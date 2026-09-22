import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

void main() {
  test('decoded whole JSON numbers normalize identically without coercion', () {
    for (final token in [
      '0',
      '0.0',
      '1',
      '1.0',
      '1e0',
      '9007199254740991',
      '9007199254740991.0',
    ]) {
      final value = Revision.fromJson(jsonDecode(token));
      expect(value.value, isA<int>());
      expect(
        jsonEncode(value.value),
        token.startsWith('9007')
            ? '9007199254740991'
            : token.startsWith('0')
                ? '0'
                : '1',
      );
    }
    for (final value in [
      null,
      true,
      '1',
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1,
      0.5,
      1.5,
      9007199254740992,
      9007199254740992.0,
    ]) {
      expect(() => Revision.fromJson(value), throwsFormatException);
    }
    for (final token in ['9007199254740993', '1e309', 'null', 'true', '"1"']) {
      expect(() => Revision.fromJson(jsonDecode(token)), throwsFormatException);
    }
  });
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
