import 'package:msgpack_codable/msgpack_codable.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

@MsgPackCodable()
class Id {
  final int id;

  Id(this.id);

  String toString() => 'Id($id)';
}

@MsgPackCodable()
class Role {
  final String name;

  Role(this.name);

  String toString() => 'Role($name)';
}

@MsgPackCodable()
class User {
  final Id id;
  final bool active;
  final String name;
  final List<Role> roles;

  User(this.id, this.active, this.name, this.roles);

  String toString() => 'User($id, $active, $name, $roles)';
}

void main() {
  // create an instance of the serializer
  final serializer = Serializer();

  // create an user instaqnce and serilize it to msgpack
  final user = User(Id(101), true, 'user101', [Role('user'), Role('admin')]);
  user.toMsgPack(serializer);

  // get the serialized bytes
  final serialized = serializer.takeBytes();

  // create an instance of the deserializer
  final deserializer = Deserializer(serialized);

  // decode the msgpack bytes to a new user instance
  final decodedUser = User.fromMsgPack(deserializer);

  print(decodedUser);
}
