This package supports easy encoding and decoding of the [MessagePack](https://msgpack.org/) format. It relies on a macro, that when applied to a user-defined Dart class, auto-generates a `fromMsgPack` decoding constructor and a `toMsgPack` encoding method. It depends on the [msgpack_dart](https://pub.dev/packages/msgpack_dart) package.

Both the package itself, and the underlying macros language feature, are considered experimental. Thus they have incomplete functionality, may be unstable, have breaking changes as the feature evolves, and are not suitable for production code.

## Applying the MsgPackCodable macro

To apply the `MsgPack` macro to a class, add it as an annotation:

```dart
import 'package:msgpack_codable/msgpack_codable.dart';

@MsgPack()
class User {
  final String name;
  final int? age;
}
```

The macro generates two members for the `User` class: a `fromMsgPack` constructor
and a `toMsgPack` method, with APIs like the following:

```dart
class User {
  User.fromMsgPack(Deserializer deserializer);
  void toMsgPack(Serializer serializer);
}
```

## Supported field types

The Dart types `num`, `int`, `double`, `bool`, `String` and `Uint8List` (from `dart:typed_data`) are supported.

In addtition, all types annotated with `@MsgPack()` are supported.

The core collection types `List` and `Map` are also supported, if their elements are supported types and have generic type arguments.

## Extension types

Additional types are supported by using extension types. Extension types are a feature of the Dart language and the MessagePack format. Both are supported.

A common case to use extension types is encoding and decoding of types not in your control. Assume you use a class `Vector3` in the class `Location` of your data model and want to encode/decode it. Because `Vector3` is defined in another library, you can't annotate it with `@MsgPack()`.

```dart
/// class in a library not in your control
class Vector3 {
  final double x;
  final double y;
  final double z;
}

/// your class using the Vector3 class
@MsgPack()
class Location {
  final Vector3 position;
  final Vector3 orientation;
}
```

### Dart extension types

The first option is to create an Dart extension type for `Vector3` and use it instead the original type in your class.

```dart
/// class in a library not in your control
extension type Vector3MsgPack(Vector3 value) implements Vector3 {
  factory Vector3MsgPack.fromMsgPack(Deserializer deserializer) {
    // implement custom deserializion here
  }

  void toMsgPack(Serializer serializer) {
    // implement custom serialization here
  }
}

@MsgPack()
class Location {
  final Vector3MsgPack position;
  final Vector3MsgPack orientation;
}
```

The `@MsgPack()` macro accepts the extension type because it has a `fromMsgPack` constructor and a `toMsgPack` method. You have to implement by hand what the macros normally generates for you.

It is planned to support the application of the `@MsgPack()` macro on Dart extension types.

### MessagePack format extension types

Another option is to tell the `@MsgPack()` macro that the `Vector3` class is an MessagePack extension type. You do that by providing the `extType` parameter.

```dart
@MsgPack(extTypes: ['Vector3'])
class Location {
  final Vector3 position;
  final Vector3 orientation;
}
```

In this case you have to implement an [ExtEncoder](https://pub.dev/documentation/msgpack_dart/latest/msgpack_dart/ExtEncoder-class.html) and [ExtDecoder](https://pub.dev/documentation/msgpack_dart/latest/msgpack_dart/ExtDecoder-class.html) and provide them the `Serializer` respectively `Deserializer`.

## Generics

Classes with generic type parameters are currently not supported.

## Inheritance

Inheritance is currently not supported.

## Enabling the macros experiment

Most tools accept the `--enable-experiment=macros` option, and appending that to your typical command line invocations should be all that is needed. For example, you can launch your Dart project like: `dart --enable-experiment=macros run`.

For the analyzer, you will want to add some configuration to an
`analysis_options.yaml` file at the root of your project:

```yaml
analyzer:
  enable-experiment:
    - macros
```

Note that `dart run` is a little bit special, in that the option must come _immediately_ following `dart` and before `run` - this is because it is an option to the Dart VM, and not the Dart script itself. For example, `dart --enable-experiment=macros run bin/my_script.dart`. This is also how the `test` package expects to be invoked, so `dart --enable-experiment=macros test`.

See also [Dart Macros](https://dart.dev/language/macros) for more details.
