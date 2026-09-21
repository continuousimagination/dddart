import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  test('revision validates the portable integer range at runtime', () {
    expect(const Revision.zero(), Revision(0));
    expect(Revision(1), Revision(1));
    expect(Revision(1).hashCode, Revision(1).hashCode);
    expect(() => Revision(-1), throwsRangeError);
    expect(() => Revision(9007199254740992), throwsRangeError);
    expect(Revision(9007199254740990).next().value, 9007199254740991);
    expect(
      Revision(9007199254740991).next,
      throwsA(isA<RevisionCapacityException>()),
    );
  });

  test('preconditions allow only absence or a positive revision', () {
    expect(const WritePrecondition.absent(), const WritePrecondition.absent());
    expect(
      WritePrecondition.atRevision(Revision(2)),
      WritePrecondition.atRevision(Revision(2)),
    );
    expect(
      () => WritePrecondition.atRevision(const Revision.zero()),
      throwsArgumentError,
    );
  });

  test('unknown write outcome retains only a safe observed classification', () {
    const failure = WriteOutcomeUnknownException(
      observedFailure: RepositoryExceptionType.forbidden,
    );
    expect(failure.type, RepositoryExceptionType.unknown);
    expect(failure.cause, isNull);
    expect(failure.accessUnavailable, isTrue);
    expect(const WriteOutcomeUnknownException().accessUnavailable, isFalse);
    expect(
      const WriteOutcomeUnknownException(
        observedFailure: RepositoryExceptionType.unauthorized,
      ).accessUnavailable,
      isTrue,
    );
    expect(
      const WriteOutcomeUnknownException(
        observedFailure: RepositoryExceptionType.connection,
      ).accessUnavailable,
      isFalse,
    );
  });
}
