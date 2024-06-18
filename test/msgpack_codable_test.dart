import 'dart:typed_data';

import 'package:msgpack_codable/msgpack_codable.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:test/test.dart';

@MsgPack()
class A {
  final num a;
  final int b;
  final double c;
  final String d;
  final bool e;
  final Uint8List f;

  A(this.a, this.b, this.c, this.d, this.e, this.f);
}

T codec<T>(void Function(Serializer) toMsgPack, T Function(Deserializer) fromMsgpack) {
  final serializer = Serializer();
  toMsgPack(serializer);
  final bytes = serializer.takeBytes();
  final deserializer = Deserializer(bytes);
  return fromMsgpack(deserializer);
}

void main() {
  test('encode/decode base types', () {
    final value = A(3.14, 1, 2.4, 'text', true, Uint8List.fromList([1, 2, 3]));
    final result = codec(value.toMsgPack, (s) => A.fromMsgPack(s));
    expect(result.a, equals(value.a));
    expect(result.b, equals(value.b));
    expect(result.c, equals(value.c));
    expect(result.d, equals(value.d));
    expect(result.e, equals(value.e));
  });
}
