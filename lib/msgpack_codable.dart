import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

/// Encodes a list to the MessagePack format. This function is helper for the [MsgPackCodable] macro.
void encodeList(Serializer serializer, List list, void Function(Serializer, dynamic) itemEncoder) {
  serializer.encode(list.length);
  for (final item in list) {
    itemEncoder(serializer, item);
  }
}

/// Decodes a list from the MessagePack format. This function is helper for the [MsgPackCodable] macro.
List<T> decodeList<T>(Deserializer deserializer, T Function(Deserializer) itemDecoder) {
  final result = <T>[];
  final length = deserializer.decode() as int;
  for (var i = 0; i < length; i++) {
    result.add(itemDecoder(deserializer));
  }
  return result;
}

/// Encodes a map to the MessagePack format. This function is helper for the [MsgPackCodable] macro.
void encodeMap(Serializer serializer, Map map, void Function(Serializer, dynamic) keyEncoder, void Function(Serializer, dynamic) valueEncoder) {
  serializer.encode(map.length);
  for (final entry in map.entries) {
    keyEncoder(serializer, entry.key);
    valueEncoder(serializer, entry.value);
  }
}

/// Decodes a map from the MessagePack format. This function is helper for the [MsgPackCodable] macro.
Map<K, V> decodeMap<K, V>(Deserializer deserializer, K Function(Deserializer) keyDecoder, V Function(Deserializer) valueDecoder) {
  final result = <K, V>{};
  final length = deserializer.decode() as int;
  for (var i = 0; i < length; i++) {
    final key = keyDecoder(deserializer);
    final value = valueDecoder(deserializer);
    result[key] = value;
  }
  return result;
}

/// A macro which adds a `fromMsgPack(Deserializer)` MessagePack decoding constructor, and a `void toMsgPack(Serializer)`
/// MessagePack encoding method to a class.
/// 
/// To use this macro, annotate your class with `@MsgPackCodable()` and enable the macros experiment (see [Dart Macros](https://dart.dev/language/macros) for full 
/// instructions). `@MsgPackCodable()` is based on the package [msgpack_dart](https://pub.dev/packages/msgpack_dart) and
/// is intended to be used in conjunction with it.
/// 
/// The implementations are derived from the fields defined directly on the annotated class. Annotated classes are not
/// allowed to have a manually defined toMsgPack method or fromMsgPack constructor.
macro class MsgPackCodable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const MsgPackCodable();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    if(clazz.typeParameters.isNotEmpty) {
      builder.report(Diagnostic(DiagnosticMessage('Generic classes are not supported by @MsgPackCodable().', target: clazz.asDiagnosticTarget), Severity.error));
      return;
    }
    final deserializerType = await builder.resolveIdentifier(_msgpackDartPackage, 'Deserializer');
    final serializerType = await builder.resolveIdentifier(_msgpackDartPackage, 'Serializer');
    builder.declareInType(DeclarationCode.fromParts(['  external ${clazz.identifier.name}.fromMsgPack(', deserializerType, ' deserializer);']));
    builder.declareInType(DeclarationCode.fromParts(['  external void toMsgPack(', serializerType, ' serializer);']));
  }
  
  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
    if(clazz.typeParameters.isNotEmpty) {
      return;
    }

    final generator = _Generator();

    await [
      _defineToMsgPack(generator, clazz, builder),
      _defineFromMsgPack(generator, clazz, builder),
    ].wait;
  }

  Future<void> _defineToMsgPack(_Generator generator, ClassDeclaration clazz, TypeDefinitionBuilder typeBuilder) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toMsgPack = methods.firstWhereOrNull((c) => c.identifier.name == 'toMsgPack');
    if (toMsgPack == null) {
      return;
    }

    final parts = [];

    final fields = await typeBuilder.fieldsOf(clazz);
    for(final field in fields) {
      parts.add('    ');
      parts.add(await generator.generateEncode(typeBuilder, field.identifier.name, field.type as NamedTypeAnnotation, field.asDiagnosticTarget));
      parts.add(';\n');
    }

    final builder = await typeBuilder.buildMethod(toMsgPack.identifier);
    builder.augment(FunctionBodyCode.fromParts([
      '{\n', 
      ...parts,
      '  }',]));
  }

  Future<void> _defineFromMsgPack(_Generator generator, ClassDeclaration clazz, TypeDefinitionBuilder typeBuilder) async {
    final constructors = await typeBuilder.constructorsOf(clazz);
    final fromMsgPack = constructors.firstWhereOrNull((c) => c.identifier.name == 'fromMsgPack');
    if(fromMsgPack == null) {
      return;
    }

    final initializers = <Code>[];
    final fields = await typeBuilder.fieldsOf(clazz);
    for(final field in fields) {
      initializers.add(RawCode.fromParts([field.identifier, ' = ', await generator.generateDecode(typeBuilder, field.type as NamedTypeAnnotation)]));
    }

    final builder = await typeBuilder.buildConstructor(fromMsgPack.identifier);
    builder.augment(initializers: initializers);
  }
}

abstract interface class _CodeGenerator {
  _TypeKind get kind;
  Future<bool> supportsType(DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type);
  Future<Code> generateEncode(_Generator generator, _Reporter reporter, DefinitionPhaseIntrospector introspector, String identifier, NamedTypeAnnotation type);
  Future<Code> generateDecode(_Generator generator, DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type);
}

class _BaseTypeCodeGenerator implements _CodeGenerator {
  @override
  _TypeKind get kind => _TypeKind.base;

  @override
  Future<bool> supportsType(TypePhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final supportedTypes = await [
      introspector.resolveIdentifier(_corePackage, 'bool'),
      introspector.resolveIdentifier(_corePackage, 'num'),
      introspector.resolveIdentifier(_corePackage, 'int'),
      introspector.resolveIdentifier(_corePackage, 'double'),
      introspector.resolveIdentifier(_corePackage, 'String'),
      introspector.resolveIdentifier(_typedDataPackage, 'Uint8List'),
    ].wait;
    return supportedTypes.map((e) => e.name).contains(type.identifier.name);
  }

  @override
  Future<Code> generateEncode(_Generator generator, _Reporter reporter, TypePhaseIntrospector introspector, String identifier, NamedTypeAnnotation type) async {
    return RawCode.fromString('serializer.encode($identifier)');
  }

  @override
  Future<Code> generateDecode(_Generator generator, TypePhaseIntrospector introspector, NamedTypeAnnotation type) async {
    return RawCode.fromString('deserializer.decode()');  
  }
}

class _ComplexTypeCodeGenerator implements _CodeGenerator {
  @override
  _TypeKind get kind => _TypeKind.complex;

  @override
  Future<bool> supportsType(DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final typeDeclaration = await introspector.declarationOf(type.identifier);
    if(typeDeclaration is TypeDeclaration) {
      final toMsgPack = (await introspector.methodsOf(typeDeclaration)).firstWhereOrNull((method) => method.identifier.name == 'toMsgPack');
      if(toMsgPack == null) {
        return false;
      }
      final fromMsgPack = (await introspector.constructorsOf(typeDeclaration)).firstWhereOrNull((method) => method.identifier.name == 'fromMsgPack');
      if(fromMsgPack == null) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<Code> generateEncode(_Generator generator, _Reporter reporter, TypePhaseIntrospector introspector, String identifier, NamedTypeAnnotation type) async {
    return RawCode.fromString('$identifier.toMsgPack(serializer)');
  }

  @override
  Future<Code> generateDecode(_Generator generator, TypePhaseIntrospector introspector, NamedTypeAnnotation type) async {
    return RawCode.fromString('${type.identifier.name}.fromMsgPack(deserializer)');  
  }
  }

class _ListTypeCodeGenerator implements _CodeGenerator {
  @override
  _TypeKind get kind => _TypeKind.array;

  @override
  Future<bool> supportsType(TypePhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final supportedTypes = await [
      introspector.resolveIdentifier(_corePackage, 'List'),
    ].wait;
    return supportedTypes.map((e) => e.name).contains(type.identifier.name);
  }

  @override
  Future<Code> generateEncode(_Generator generator, _Reporter reporter, DefinitionPhaseIntrospector introspector, String identifier, NamedTypeAnnotation type) async {
    final encodeListFunction = await introspector.resolveIdentifier(_msgpackCodablePackage, 'encodeList');
    final typeArg = type.typeArguments.firstOrNull;
    if (typeArg != null) {
      final typeKind = await generator.kindOf(introspector, typeArg as NamedTypeAnnotation);
      if (typeKind == _TypeKind.base) {
        return RawCode.fromString('serializer.encode($identifier)');
      } else if (typeKind == _TypeKind.complex || typeKind == _TypeKind.array) {
        return RawCode.fromParts([encodeListFunction, '(serializer, $identifier, (serializer, item) => ', await generator.generateEncode(introspector, 'item', typeArg, typeArg.asDiagnosticTarget), ')']);
      } else {
        throw ArgumentError('Unsupported type ${typeArg.identifier.name}!');
      }
    } else {
      reporter('List without type argument is not supported by @MsgPackCodable().');
      return RawCode.fromString('/* List without type argument is not supported by @MsgPackCodable(). */');
    }
  }

  @override
  Future<Code> generateDecode(_Generator generator, DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final decodeListFunction = await introspector.resolveIdentifier(_msgpackCodablePackage, 'decodeList');
    final listType = await introspector.resolveIdentifier(_corePackage, 'List');
    final typeArg = type.typeArguments.firstOrNull;
    if(typeArg != null) {
      final typeKind = await generator.kindOf(introspector, typeArg as NamedTypeAnnotation);
      if (typeKind == _TypeKind.base) {
        return RawCode.fromParts(['(deserializer.decode() as ', listType, ').cast<', typeArg.code, '>()']);  
      } else if (typeKind == _TypeKind.unsupported) {
        return RawCode.fromString('[]');
      } else {
        return RawCode.fromParts([decodeListFunction, '(deserializer, (d) => ', await generator.generateDecode(introspector, typeArg), ')']);  
      }
    } else {
      return RawCode.fromString('/* List without type argument is not supported by @MsgPackCodable(). */');
    }
  }
}

final _corePackage = Uri.parse('dart:core');
final _typedDataPackage = Uri.parse('dart:typed_data');
final _msgpackCodablePackage = Uri.parse('package:msgpack_codable/msgpack_codable.dart');
final _msgpackDartPackage = Uri.parse('package:msgpack_dart/msgpack_dart.dart');

typedef _Reporter = void Function(String message);

enum _TypeKind {
  base,
  complex,
  array,
  map,
  unsupported,
}

class _MapTypeCodeGenerator implements _CodeGenerator {
  @override
  _TypeKind get kind => _TypeKind.map;

  @override
  Future<bool> supportsType(TypePhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final supportedTypes = await [
      introspector.resolveIdentifier(_corePackage, 'Map'),
    ].wait;
    return supportedTypes.map((e) => e.name).contains(type.identifier.name);
  }

  @override
  Future<Code> generateEncode(_Generator generator, _Reporter reporter, DefinitionPhaseIntrospector introspector, String identifier, NamedTypeAnnotation type) async {
    final encodeMapFunction = await introspector.resolveIdentifier(_msgpackCodablePackage, 'encodeMap');
    final typeArgKey = type.typeArguments.firstOrNull;
    final typeArgValue = type.typeArguments.lastOrNull;
    if(typeArgKey == null && typeArgValue == null) {
      return RawCode.fromString('serializer.encode($identifier)');
    } else {
      final typeKindKey = await generator.kindOf(introspector, typeArgKey as NamedTypeAnnotation);
      final typeKindValue = await generator.kindOf(introspector, typeArgValue as NamedTypeAnnotation);
      if (typeKindKey == _TypeKind.base && typeKindValue == _TypeKind.base) {
        return RawCode.fromString('serializer.encode($identifier)');
      } else if (typeKindKey == _TypeKind.unsupported || typeKindValue == _TypeKind.unsupported) {
        if(typeKindKey == _TypeKind.unsupported) {
          reporter('Type argument ${typeArgKey.identifier.name} of Map is not supported by @MsgPackCodable().');
        }
        if(typeKindValue == _TypeKind.unsupported) {
          reporter('Type argument ${typeArgValue.identifier.name} of Map is not supported by @MsgPackCodable().');
        }
        return RawCode.fromString('/* Type argument ${typeArgKey.identifier.name} or ${typeArgValue.identifier.name} of Map is not supported by @MsgPackCodable(). */');  
      } else {
        return RawCode.fromParts([encodeMapFunction, '(serializer, $identifier, (serializer, key) => ', await generator.generateEncode(introspector, 'key', typeArgKey, type.asDiagnosticTarget), ', (serializer, value) => ', await generator.generateEncode(introspector, 'value', typeArgValue, type.asDiagnosticTarget), ')']);
      }
    }
  }

  @override
  Future<Code> generateDecode(_Generator generator, DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type) async {
    final decodeMapFunction = await introspector.resolveIdentifier(_msgpackCodablePackage, 'decodeMap');
    final mapType = await introspector.resolveIdentifier(_corePackage, 'Map');
    final typeArgKey = type.typeArguments.firstOrNull;
    final typeArgValue = type.typeArguments.lastOrNull;
    if(typeArgKey != null && typeArgValue != null) {
      final typeKindKey = await generator.kindOf(introspector, typeArgKey as NamedTypeAnnotation);
      final typeKindValue = await generator.kindOf(introspector, typeArgValue as NamedTypeAnnotation);
      if (typeKindKey == _TypeKind.base && typeKindValue == _TypeKind.base) {
        return RawCode.fromParts(['(deserializer.decode() as ', mapType, ').cast<', typeArgKey.code, ', ', typeArgValue.code, '>()']);
      } else if (typeKindKey == _TypeKind.unsupported || typeKindValue == _TypeKind.unsupported) {
        return RawCode.fromString('{}');
      } else {
        return RawCode.fromParts([decodeMapFunction, '(deserializer, (deserializer) => ', await generator.generateDecode(introspector, typeArgKey), ', (deserializer) => ', await generator.generateDecode(introspector, typeArgValue), ')']);  
      }
    } else {
      return RawCode.fromString('/* Map without type arguments is not supported by @MsgPackCodable(). */');
    }
  }
}

class _Generator {
  final List<_CodeGenerator> generators = [
      _BaseTypeCodeGenerator(),
      _ComplexTypeCodeGenerator(),
      _ListTypeCodeGenerator(),
      _MapTypeCodeGenerator(),
    ];

  _Generator();

  Future<_TypeKind> kindOf(DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type) async {
    for(final generator in generators) {
      if(await generator.supportsType(introspector, type)) {
        return generator.kind;
      }
    }
    return _TypeKind.unsupported;
  }

  Future<bool> supportsField(DefinitionPhaseIntrospector introspector, FieldDeclaration field) async {
    for(final generator in generators) {
      if(await generator.supportsType(introspector, field.type as NamedTypeAnnotation)) {
        return true;
      }
    }
    return false;
  }

  Future<Code> generateEncode(DefinitionPhaseIntrospector introspector, String identifier, NamedTypeAnnotation type, DiagnosticTarget diagnosticTarget) async {
    for(final generator in generators) {
      if((await generator.supportsType(introspector, type))) {
        return generator.generateEncode(this, (message) => (introspector as Builder).report(Diagnostic(DiagnosticMessage(message, target: diagnosticTarget), Severity.error)), introspector, identifier, type);
      }
    }
    (introspector as Builder).report(Diagnostic(DiagnosticMessage('Type ${type.identifier.name} of field $identifier is not supported by @MsgPackCodable().', target: diagnosticTarget), Severity.error));      
    return RawCode.fromString('/* Type ${type.identifier.name} of field $identifier is not supported by @MsgPackCodable(). */');
  }

  Future<Code> generateDecode(DefinitionPhaseIntrospector introspector, NamedTypeAnnotation type) async {
    for(final generator in generators) {
      if((await generator.supportsType(introspector, type))) {
        return generator.generateDecode(this, introspector, type);
      }
    }
    return RawCode.fromString('/* Type ${type.identifier.name} is not supported by @MsgPackCodable(). */');
  }
}