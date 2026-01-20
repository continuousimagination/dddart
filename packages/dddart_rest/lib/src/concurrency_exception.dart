import 'package:dddart/dddart.dart';

/// Exception thrown when a conditional request fails due to ETag mismatch
///
/// This exception indicates that the resource was modified by another client
/// between when it was fetched and when the update was attempted.
///
/// Clients should handle this by:
/// 1. Fetching the latest version of the resource
/// 2. Re-applying their changes
/// 3. Retrying the update
///
/// Example:
/// ```dart
/// try {
///   await repository.save(user);
/// } on ConcurrencyException catch (e) {
///   // Resource was modified by another client
///   final latest = await repository.getById(user.id);
///   // Merge changes and retry
/// }
/// ```
class ConcurrencyException implements Exception {
  /// Creates a concurrency exception
  ///
  /// Parameters:
  /// - [message]: Description of the concurrency conflict
  /// - [aggregateId]: ID of the aggregate that had the conflict
  /// - [providedETag]: The ETag that was provided in the If-Match header
  /// - [currentETag]: The current ETag of the resource
  ConcurrencyException(
    this.message,
    this.aggregateId, {
    this.providedETag,
    this.currentETag,
  });

  /// Description of the concurrency conflict
  final String message;

  /// ID of the aggregate that had the conflict
  final UuidValue aggregateId;

  /// The ETag that was provided in the If-Match header
  final String? providedETag;

  /// The current ETag of the resource
  final String? currentETag;

  @override
  String toString() {
    final buffer = StringBuffer('ConcurrencyException: $message');
    buffer.write(' (ID: $aggregateId)');
    if (providedETag != null && currentETag != null) {
      buffer.write(' [provided: $providedETag, current: $currentETag]');
    }
    return buffer.toString();
  }
}
