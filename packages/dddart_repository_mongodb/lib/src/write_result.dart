import 'package:dddart/dddart.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Validates acknowledged single-document results before publication or success.
///
/// MongoDB can return write errors without throwing. Only an `_id` duplicate
/// during create-if-absent is a revision conflict; other unique indexes remain
/// duplicate errors. Missing acknowledgment never proves a condition failure.
void validateMongoWriteResult<I extends Identity>(
  WriteResult result, {
  required I id,
  ExpectedRevision? expected,
}) {
  final error = result.writeError;
  if (error != null) {
    if (error.code == 11000) {
      if ((expected?.isAbsent ?? false) &&
          (error.errmsg?.contains('index: _id_ ') ?? false)) {
        throw RevisionConflictException(id, expected!);
      }
      throw RepositoryException(
        error.errmsg ?? 'Duplicate MongoDB key',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }
    throw RepositoryException(
      error.errmsg ?? 'MongoDB rejected the write',
      type: error.code == 121
          ? RepositoryExceptionType.constraint
          : RepositoryExceptionType.unknown,
      cause: error,
    );
  }
  if (!result.operationSucceeded || !result.isAcknowledged) {
    throw ConditionalWriteUncertainException(cause: result);
  }
}
