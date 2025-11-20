/// Exception thrown by MongoDB repository operations.
///
/// This exception is used for MongoDB-specific errors that occur during
/// connection management or repository operations.
class MongoRepositoryException implements Exception {
  /// Creates a MongoDB repository exception.
  ///
  /// [message] - A description of the error
  /// [cause] - The underlying exception that caused this error (optional)
  /// [stackTrace] - The stack trace where the error occurred (optional)
  const MongoRepositoryException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  /// A description of the error.
  final String message;

  /// The underlying exception that caused this error.
  final Object? cause;

  /// The stack trace where the error occurred.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('MongoRepositoryException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }
}
