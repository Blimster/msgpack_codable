This package supports easy encoding and decoding of the [MessagePack](https://msgpack.org/) format. It relies on a macro, that when applied to a user-defined Dart class, auto-generates a `fromMsgPack` decoding constructor and a `toMsgPack` encoding method.

Both the package itself, and the underlying macros language feature, are considered experimental. Thus they have incomplete functionality, may be unstable, have breaking changes as the feature evolves, and are not suitable for production code.

## Applying the MsgPackCodable macro

To apply the `MsgPackCodable` macro to a class, add it as an annotation:

```dart
import 'package:msgpack_codable/msgpack_codable.dart';

@MsgPackCodable()
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

In addtition, all types annotated with `@MsgPackCodable()` are supported.

The core collection types `List` and `Map` are also supported, if their elements are supported types and have generic type arguments.

## Generics

Classes with generic type parameters are not supported.

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
