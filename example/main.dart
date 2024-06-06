import 'package:msgpack_codable/msgpack_codable.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

@MsgpackCodable()
class Id {
  final String id;

  Id(this.id);

  String toString() => 'Id($id)';
}

@MsgpackCodable()
class User {
  final Id id;
  final String name;
  final List<String> roles;

  User(this.id, this.name, this.roles);

  String toString() => 'User(id: $id, name: $name, roles: $roles)';
}

List<String> foo() => ['a', 'b', 'c'];

class Test {
  final List<String> list;

  Test() : list = foo();
}

void main() {
  final serializer = Serializer();

  final user = User(Id('1910'), 'fcstp', ['admin', 'user']);
  user.toMsgPack(serializer);

  final serialized = serializer.takeBytes();

  final deserializer = Deserializer(serialized);
  final decodedUser = User.fromMsgPack(deserializer);

  print(decodedUser);
}
