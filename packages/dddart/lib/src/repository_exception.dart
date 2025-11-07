/// Exception thrown when a repository operation fails.
class RepositoryException implements Exception {
  /// Creates a repository exception with a message and optional type and cause.
  const RepositoryException(
    this.message, {
    this.type = RepositoryExceptionType.unknown,
    this.cause,
  });

  /// Human-readable error message describing what went wrong.
  final String message;

  /// The type of repository error that occurred.
  final RepositoryExceptionType type;

  /// Optional underlying cause of the exception.
  ///
  /// This can be used to wrap lower-level exceptions while providing
  /// a repository-specific error message.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'RepositoryException: $message (type: $type, cause: $cause)';
    }
    return 'RepositoryException: $message (type: $type)';
  }
}

/// Types of repository exceptions that can occur during operations.
enum RepositoryExceptionType {
  /// The requested aggregate was not found in the repository.
  notFound,

  /// A duplicate aggregate already exists (e.g., unique constraint violation).
  duplicate,

  /// The operation violated a data constraint.
  constraint,

  /// A connection or network error occurred while accessing the data store.
  connection,

  /// The operation timed out before completing.
  timeout,

  /// An unknown or unexpected error occurred.
  unknown,
}
