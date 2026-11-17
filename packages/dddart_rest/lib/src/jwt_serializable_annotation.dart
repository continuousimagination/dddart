import 'package:meta/meta.dart';

/// Annotation to mark classes as JWT-serializable claims.
///
/// Classes annotated with `@JwtSerializable()` have convenience extension
/// methods generated on a compatible `JwtAuthHandler` for converting claims
/// to and from JSON. These helpers are not wired into the handler constructor
/// automatically; applications must still provide the handler's claims loader,
/// parser, and serializer callbacks explicitly.
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/README.md).
@immutable
class JwtSerializable {
  /// Creates a JwtSerializable annotation.
  const JwtSerializable();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JwtSerializable;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'JwtSerializable()';
}
