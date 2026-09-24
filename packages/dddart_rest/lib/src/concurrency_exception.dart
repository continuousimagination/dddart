import 'package:dddart/dddart.dart';

/// Describes a conditional request failure caused by an ETag mismatch.
///
/// A mismatch means the supplied ETag differs from the current ETag. It does not
/// identify what changed the aggregate and does not make a later repository
/// save atomic.
///
/// Clients can respond by:
/// 1. Fetching the latest version of the resource
/// 2. Re-applying their changes
/// 3. Retrying the update
///
/// `CrudResource` currently returns a 412 response directly when ETags differ;
/// ordinary [Repository.save] does not throw this exception.
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
