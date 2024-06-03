import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

macro class MsgpackCodable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const MsgpackCodable();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) {
    builder.declareInLibrary(DeclarationCode.fromParts(['import \'package:msgpack_dart/msgpack_dart.dart\' as msgpck;']));  
    builder.declareInType(DeclarationCode.fromParts(['  external void toMsgPack(msgpck.Serializer serializer);']));
  }
  
  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
    await _defineToMsgPack(clazz, builder);
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
      parts.add('serializer.encode(${field.identifier.name});');
      //builder.report(Diagnostic(DiagnosticMessage(field.identifier.name), Severity.warning));
      //print(field.identifier.name);
    }

    final builder = await typeBuilder.buildMethod(toMsgPack.identifier);
    builder.augment(FunctionBodyCode.fromParts([
      '{\n final i = 10;\n', 
      '',
      '}',]));
  }
}
