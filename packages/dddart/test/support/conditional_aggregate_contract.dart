import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

/// Reusable black-box tests; adapters provide two handles to the same storage.
void conditionalAggregateContract<T extends AggregateRoot<I>,
    I extends Identity>({
  required Future<(Repository<T, I>, Repository<T, I>, Future<void> Function())>
          Function()
      open,
  required T Function(int value, I? id) create,
  required int Function(T) value,
}) {
  late Repository<T, I> left;
  late Repository<T, I> right;
  late ConditionalAggregateRepository<T, I> first;
  late ConditionalAggregateRepository<T, I> second;
  setUp(() async {
    final fixture = await open();
    left = fixture.$1;
    right = fixture.$2;
    first = requireConditionalAggregateRepository(left);
    second = requireConditionalAggregateRepository(right);
    addTearDown(fixture.$3);
  });

  test('two snapshots at one revision yield exactly one committed writer',
      () async {
    final original = create(0, null);
    await left.save(original);
    final a = await first.getVersioned(original.id);
    final b = await second.getVersioned(original.id);
    expect(a.revision, b.revision);
    final start = Completer<void>();
    Future<Object> write(
      ConditionalAggregateRepository<T, I> repository,
      int next,
    ) async {
      await start.future;
      try {
        return await repository.saveConditional(
          create(next, original.id),
          expected: ExpectedRevision.match(a.revision),
        );
      } on RevisionConflictException<I> catch (error) {
        return error;
      }
    }

    final one = write(first, 1);
    final two = write(second, 2);
    start.complete();
    final results = await Future.wait([one, two]);
    expect(results.whereType<String>(), hasLength(1));
    expect(results.whereType<RevisionConflictException<I>>(), hasLength(1));
    final committed = await first.getVersioned(original.id);
    expect(committed.revision, results.whereType<String>().single);
    expect(value(committed.aggregate), results.first is String ? 1 : 2);
  });

  test('ordinary and identical saves invalidate revisions', () async {
    final original = create(0, null);
    await left.save(original);
    final old = await first.getVersioned(original.id);
    await right.save(create(0, original.id));
    final next = await first.getVersioned(original.id);
    expect(next.revision, isNot(old.revision));
    await expectLater(
      first.saveConditional(
        create(9, original.id),
        expected: ExpectedRevision.match(old.revision),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    final revision = await first.saveConditional(
      create(0, original.id),
      expected: ExpectedRevision.match(next.revision),
    );
    expect(revision, isNot(next.revision));
    expect((await first.getVersioned(original.id)).revision, revision);
  });

  test('create, missing, conditional delete and ABA semantics', () async {
    final original = create(0, null);
    await expectLater(
      first.getVersioned(original.id),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
    await first.deleteConditional(
      original.id,
      expected: const ExpectedRevision.absent(),
    );
    await expectLater(
      first.saveConditional(
        original,
        expected: const ExpectedRevision.match('unknown-token'),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    final revision = await first.saveConditional(
      original,
      expected: const ExpectedRevision.absent(),
    );
    await expectLater(
      second.saveConditional(
        create(8, original.id),
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    await expectLater(
      second.deleteConditional(
        original.id,
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    await first.deleteConditional(
      original.id,
      expected: ExpectedRevision.match(revision),
    );
    await expectLater(
      second.deleteConditional(
        original.id,
        expected: ExpectedRevision.match(revision),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    await right.save(create(3, original.id));
    final recreated = await first.getVersioned(original.id);
    expect(recreated.revision, isNot(revision));
    await expectLater(
      first.saveConditional(
        create(8, original.id),
        expected: ExpectedRevision.match(revision),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    expect(value((await first.getVersioned(original.id)).aggregate), 3);
  });

  test('tokens cannot authorize a different identity', () async {
    final a = create(1, null);
    final b = create(2, null);
    await left.save(a);
    await right.save(b);
    final revision = (await first.getVersioned(a.id)).revision;
    await expectLater(
      second.saveConditional(
        create(8, b.id),
        expected: ExpectedRevision.match(revision),
      ),
      throwsA(isA<RevisionConflictException<I>>()),
    );
    expect(value(await right.getById(b.id)), 2);
  });

  test('empty and malformed conditions never become unconditional writes',
      () async {
    final original = create(0, null);
    await left.save(original);
    final old = await first.getVersioned(original.id);
    for (final token in ['', ' ', 'bad\ntoken']) {
      await expectLater(
        first.saveConditional(
          create(9, original.id),
          expected: ExpectedRevision.match(token),
        ),
        throwsArgumentError,
      );
      await expectLater(
        first.deleteConditional(
          original.id,
          expected: ExpectedRevision.match(token),
        ),
        throwsArgumentError,
      );
    }
    final current = await first.getVersioned(original.id);
    expect(current.revision, old.revision);
    expect(value(current.aggregate), 0);
  });
}
