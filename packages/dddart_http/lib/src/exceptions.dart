/// Exception thrown when client requests unsupported media type
/// 
/// This exception is thrown during content negotiation when:
/// - A client sends a request with an unsupported Content-Type header (POST/PUT)
/// - A client requests a response with an unsupported Accept header (GET)
/// 
/// The exception is mapped to HTTP status codes:
/// - 415 Unsupported Media Type (for Content-Type issues)
/// - 406 Not Acceptable (for Accept header issues)
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
