/// Exception retained for unsupported response media type failures.
///
/// The REST error mapper maps this exception to 406 Not Acceptable. `CrudResource`
/// validates its JSON-only Accept and Content-Type contract directly, returning
/// 406 or 415 before invoking request side effects.
class UnsupportedMediaTypeException implements Exception {
  /// Creates an UnsupportedMediaTypeException with the given message
  ///
  /// The message should describe which media type was requested and
  /// which media types are supported.
  UnsupportedMediaTypeException(this.message);

  /// Human-readable error message describing the unsupported media type
  final String message;

  @override
  String toString() => message;
}
