import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

final _msgpackDart = Uri.parse('package:msgpack_dart/msgpack_dart.dart');

const _supportedBaseTypes = [
  'bool',
  'num',
  'double',
  'int',
  'String'];

const _supportedArrayTypes = [];

bool _isBaseType(TypeAnnotation type) {
  return _supportedBaseTypes.contains((type as NamedTypeAnnotation).identifier.name);
}

bool _isArrayType(TypeAnnotation type) {
  return _supportedArrayTypes.contains((type as NamedTypeAnnotation).identifier.name);
}

Future<bool> _isSupportedType(TypeDefinitionBuilder builder, TypeAnnotation type) async {
  if(_isBaseType(type)) {
    return true;
  }
  if(_isArrayType(type)) {
    return true;
  }
  final typeDeclaration = await builder.declarationOf((type as NamedTypeAnnotation).identifier);
  if(typeDeclaration is TypeDeclaration) {
    final toMsgPack = (await builder.methodsOf(typeDeclaration)).firstWhereOrNull((method) => method.identifier.name == 'toMsgPack');
    if(toMsgPack == null) {
      return false;
    }
    final fromMsgPack = (await builder.constructorsOf(typeDeclaration)).firstWhereOrNull((method) => method.identifier.name == 'fromMsgPack');
    if(fromMsgPack == null) {
      return false;
    }
  }
  return true;
}

macro class MsgpackCodable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const MsgpackCodable();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    final deserializerType = await builder.resolveIdentifier(_msgpackDart, 'Deserializer');
    final serializerType = await builder.resolveIdentifier(_msgpackDart, 'Serializer');
    builder.declareInType(DeclarationCode.fromParts(['  external ${clazz.identifier.name}.fromMsgPack(', deserializerType, ' deserializer);']));
    builder.declareInType(DeclarationCode.fromParts(['  external void toMsgPack(', serializerType, ' serializer);']));
  }
  
  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
    await (
      _defineFromMsgPack(clazz, builder),
      _defineToMsgPack(clazz, builder),
    ).wait;
  }

  Future<void> _defineFromMsgPack(ClassDeclaration clazz, TypeDefinitionBuilder typeBuilder) async {
    final constructors = await typeBuilder.constructorsOf(clazz);
    final fromMsgPack = constructors.firstWhereOrNull((c) => c.identifier.name == 'fromMsgPack');
    if(fromMsgPack == null) {
      return;
    }

    final parts = <String>[];
    final fields = await typeBuilder.fieldsOf(clazz);
    for(final field in fields) {
      final type = (field.type as NamedTypeAnnotation);
      if ((await _isSupportedType(typeBuilder, field.type)) == false) {
        typeBuilder.report(Diagnostic(DiagnosticMessage('Type \'${type.identifier.name}\' is not supported by @MsgPackCodable().', target: type.asDiagnosticTarget), Severity.error));
      } else {
        if(_isBaseType(field.type)) {
          parts.add('${field.identifier.name} = deserializer.decode()');
        } else {
          parts.add('${field.identifier.name} = ${type.identifier.name}.fromMsgPack(deserializer)');
        }
      }
    }

    final builder = await typeBuilder.buildConstructor(fromMsgPack.identifier);
    builder.augment(initializers: parts.map((part) => RawCode.fromString(part)).toList());
  }

  Future<void> _defineToMsgPack(ClassDeclaration clazz, TypeDefinitionBuilder typeBuilder) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toMsgPack = methods.firstWhereOrNull((c) => c.identifier.name == 'toMsgPack');
    if (toMsgPack == null) {
      return;
    }

    final parts = <String>[];

    final fields = await typeBuilder.fieldsOf(clazz);
    for(final field in fields) {
      if(_isBaseType(field.type)) {
        parts.add('    serializer.encode(${field.identifier.name});\n');
      } else {
        parts.add('    ${field.identifier.name}.toMsgPack(serializer);\n');
      }
    }

    final builder = await typeBuilder.buildMethod(toMsgPack.identifier);
    builder.augment(FunctionBodyCode.fromParts([
      '{\n', 
      ...parts,
      '  }',]));
  }
}
