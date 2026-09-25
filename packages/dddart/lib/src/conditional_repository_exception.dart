import 'package:dddart/src/repository_exception.dart';

/// Storage rejected the supplied atomic expectation without changing state.
class PreconditionFailedException extends RepositoryException {
  /// Creates a safe precondition failure.
  const PreconditionFailedException()
      : super(
          'Write precondition failed.',
          type: RepositoryExceptionType.constraint,
        );
}

/// A protected mutation omitted its mandatory expectation.
class PreconditionRequiredException extends RepositoryException {
  /// Creates a safe missing-precondition failure.
  const PreconditionRequiredException()
      : super(
          'Write precondition required.',
          type: RepositoryExceptionType.constraint,
        );
}

/// The configured repository cannot honor the requested persistence contract.
class RepositoryCapabilityException extends RepositoryException {
  /// Creates a safe capability failure.
  const RepositoryCapabilityException()
      : super('Repository capability unavailable.');
}

/// Advancing a revision would exceed the portable integer capacity.
class RevisionCapacityException extends RepositoryException {
  /// Creates a safe capacity failure.
  const RevisionCapacityException()
      : super(
          'Revision capacity exceeded.',
          type: RepositoryExceptionType.constraint,
        );
}

/// A write may have been dispatched; its logical outcome is not acknowledged.
///
/// A transport may deliver multiple physical attempts. The observed final
/// failure is not proof that an earlier attempt did not commit. No raw cause,
/// response body, credential or arbitrary message is retained here.
class WriteOutcomeUnknownException extends RepositoryException {
  /// Creates uncertainty with an optional safe final failure classification.
  const WriteOutcomeUnknownException({this.observedFailure})
      : super('Write outcome is unknown.');

  /// Safe classification of the final observed transport/repository failure.
  final RepositoryExceptionType? observedFailure;

  /// Whether automatic recovery reads must stop until access is re-established.
  bool get accessUnavailable =>
      observedFailure == RepositoryExceptionType.unauthorized ||
      observedFailure == RepositoryExceptionType.forbidden;
}
