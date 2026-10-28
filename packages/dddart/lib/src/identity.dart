import 'package:dddart/src/value.dart';

/// An immutable domain identity, including every component of its scope.
///
/// Define final fields and include them in [props]. Equality preserves the
/// concrete identity kind as well as its values. Storage and wire encodings
/// belong to explicit boundary codecs, not to [toString].
abstract class Identity extends Value {
  /// Creates an immutable identity.
  const Identity();
}
