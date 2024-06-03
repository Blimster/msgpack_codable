import 'package:json/json.dart';
import 'package:msgpack_codable/msgpack_codable.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

@MsgpackCodable()
@JsonCodable()
class User {
  final String name;

  User(this.name);
}

void main() {
  print('hello, macros!');

  final serializer = Serializer();

  final user = User('my name');
  user.toMsgPack(serializer);

  final serialized = serializer.takeBytes();

  final deserializer = Deserializer(serialized);
}
