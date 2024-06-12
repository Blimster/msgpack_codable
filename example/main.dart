import 'dart:typed_data';

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
  final double score;
  final Uint8List data;
  final List<Role> roles;
  final Map<String, Id> map;
  final List<List<Id>> nestedList;

  User(this.id, this.active, this.name, this.score, this.data, this.roles, this.map, this.nestedList);

  String toString() => 'User($id, $active, $name, $score, $data, $roles, $map, $nestedList)';
}

void main() {
  final serializer = Serializer();

  final user = User(Id(1910), true, 'fcstp', 3.14, Uint8List.fromList([1, 2, 3]), [
    Role('user'),
    Role('admin')
  ], {'a': Id(1), 'b': Id(2)}, [
    [Id(1), Id(2)],
    [Id(3), Id(4)]
  ]);
  user.toMsgPack(serializer);

  final serialized = serializer.takeBytes();

  final deserializer = Deserializer(serialized);
  final decodedUser = User.fromMsgPack(deserializer);

  print(decodedUser);
}
