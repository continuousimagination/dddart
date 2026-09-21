import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

class _Record extends VersionedAggregateRoot {
  _Record({
    required this.words,
    super.id,
    super.createdAt,
    super.updatedAt,
    super.revision,
  });
  final List<String> words;
  _Record copy(Revision revision) => _Record(
        words: [...words],
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        revision: revision,
      );
}

void main() {
  late InMemoryConditionalRepository<_Record> repository;
  setUp(
    () => repository = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) => value.copy(revision),
    ),
  );

  test('save returns accepted independent state without mutating proposal',
      () async {
    final proposal = _Record(words: ['first']);
    final accepted = await repository.save(
      proposal,
      precondition: const WritePrecondition.absent(),
    );
    expect(accepted.revision, Revision(1));
    expect(proposal.revision, const Revision.zero());
    expect(identical(proposal, accepted), isFalse);
    proposal.words.add('proposal');
    accepted.words.add('accepted');
    final observed = await repository.getById(proposal.id);
    expect(observed.words, ['first']);
    observed.words.clear();
    observed.updatedAt = DateTime.utc(1990);
    expect((await repository.getById(proposal.id)).words, ['first']);
    expect(
      (await repository.getById(proposal.id)).updatedAt,
      proposal.updatedAt,
    );
  });

  test('concurrent creates and updates each have exactly one winner', () async {
    final proposal = _Record(words: ['initial']);
    Future<Object> attempt(_Record value, WritePrecondition condition) async {
      try {
        return await repository.save(value, precondition: condition);
      } on PreconditionFailedException catch (error) {
        return error;
      }
    }

    final creates = await Future.wait([
      attempt(proposal, const WritePrecondition.absent()),
      attempt(proposal, const WritePrecondition.absent()),
    ]);
    expect(creates.whereType<_Record>(), hasLength(1));
    expect(creates.whereType<PreconditionFailedException>(), hasLength(1));
    final first = creates.whereType<_Record>().single;
    final updates = await Future.wait([
      attempt(first, WritePrecondition.atRevision(first.revision)),
      attempt(first, WritePrecondition.atRevision(first.revision)),
    ]);
    expect(updates.whereType<_Record>().single.revision, Revision(2));
    expect(updates.whereType<PreconditionFailedException>(), hasLength(1));
    expect((await repository.getById(first.id)).revision, Revision(2));
  });

  test('retirement rejects stale update, repeated delete and recreation',
      () async {
    final proposal = _Record(words: ['private']);
    final saved = await repository.save(
      proposal,
      precondition: const WritePrecondition.absent(),
    );
    await repository.deleteById(
      saved.id,
      precondition: WritePrecondition.atRevision(saved.revision),
    );
    await expectLater(
      repository.getById(saved.id),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
    await expectLater(
      repository.save(
        proposal,
        precondition: const WritePrecondition.absent(),
      ),
      throwsA(isA<PreconditionFailedException>()),
    );
    await expectLater(
      repository.save(
        saved,
        precondition: WritePrecondition.atRevision(saved.revision),
      ),
      throwsA(isA<PreconditionFailedException>()),
    );
    await expectLater(
      repository.deleteById(
        saved.id,
        precondition: WritePrecondition.atRevision(saved.revision),
      ),
      throwsA(isA<PreconditionFailedException>()),
    );
  });

  test('precondition/proposal mismatch and absent delete fail before copying',
      () async {
    var copies = 0;
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) {
        copies++;
        return value.copy(revision);
      },
    );
    await expectLater(
      guarded.save(
        _Record(words: []),
        precondition: WritePrecondition.atRevision(Revision(1)),
      ),
      throwsArgumentError,
    );
    await expectLater(
      guarded.deleteById(
        UuidValue.generate(),
        precondition: const WritePrecondition.absent(),
      ),
      throwsArgumentError,
    );
    expect(copies, 0);
  });

  test('return-copy failure occurs before committing', () async {
    var calls = 0;
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) {
        if (++calls == 2) throw StateError('copy failed');
        return value.copy(revision);
      },
    );
    final proposal = _Record(words: []);
    await expectLater(
      guarded.save(proposal, precondition: const WritePrecondition.absent()),
      throwsStateError,
    );
    await expectLater(
      guarded.getById(proposal.id),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.notFound),
      ),
    );
  });

  test(
      'invalid copier identity, revision, timestamp and alias fail before commit',
      () async {
    final proposal = _Record(words: []);
    for (final copy in <_Record Function(_Record, Revision)>[
      (value, revision) => value,
      (value, revision) => _Record(words: [], revision: revision),
      (value, revision) => value.copy(const Revision.zero()),
      (value, revision) => _Record(
            words: [],
            id: value.id,
            createdAt: DateTime.utc(1990),
            updatedAt: value.updatedAt,
            revision: revision,
          ),
    ]) {
      final guarded =
          InMemoryConditionalRepository<_Record>(copyWithRevision: copy);
      await expectLater(
        guarded.save(
          proposal,
          precondition: const WritePrecondition.absent(),
        ),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      await expectLater(
        guarded.getById(proposal.id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    }
  });

  test('legacy repository refuses versioned type and widened saves', () async {
    expect(
      InMemoryRepository<_Record>.new,
      throwsA(isA<RepositoryCapabilityException>()),
    );
    final widened = InMemoryRepository<AggregateRoot>();
    await expectLater(
      widened.save(_Record(words: [])),
      throwsA(isA<RepositoryCapabilityException>()),
    );
    expect(await widened.getAll(), isEmpty);
  });
  test('distinct racing drafts retain the winner in either invocation order',
      () async {
    for (final reverse in [false, true]) {
      final initial = await repository.save(
        _Record(words: ['initial']),
        precondition: const WritePrecondition.absent(),
      );
      final a = initial.copy(initial.revision)..words[0] = 'A';
      final b = initial.copy(initial.revision)..words[0] = 'B';
      Future<_Record?> attempt(_Record value) async {
        try {
          return await repository.save(
            value,
            precondition: WritePrecondition.atRevision(value.revision),
          );
        } on PreconditionFailedException {
          return null;
        }
      }

      final results =
          await Future.wait((reverse ? [b, a] : [a, b]).map(attempt));
      final winner = results.whereType<_Record>().single;
      expect(winner.words, reverse ? ['B'] : ['A']);
      expect((await repository.getById(initial.id)).words, winner.words);
      final later = winner.copy(winner.revision)..words[0] = 'newer';
      final accepted = await repository.save(
        later,
        precondition: WritePrecondition.atRevision(later.revision),
      );
      await expectLater(
        repository.save(
          a,
          precondition: WritePrecondition.atRevision(a.revision),
        ),
        throwsA(isA<PreconditionFailedException>()),
      );
      final observed = await repository.getById(initial.id);
      expect(observed.revision, accepted.revision);
      expect(observed.words, ['newer']);
    }
  });

  test('every proposal mismatch avoids copier and preserves stored state',
      () async {
    var copies = 0;
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) {
        copies++;
        return value.copy(revision);
      },
    );
    final initial = await guarded.save(
      _Record(words: ['old']),
      precondition: const WritePrecondition.absent(),
    );
    for (final pair in [
      (initial, const WritePrecondition.absent()),
      (initial.copy(Revision(2)), WritePrecondition.atRevision(Revision(1))),
      (initial, WritePrecondition.atRevision(Revision(2))),
    ]) {
      final before = copies;
      await expectLater(
        guarded.save(pair.$1, precondition: pair.$2),
        throwsArgumentError,
      );
      expect(copies, before);
      expect((await guarded.getById(initial.id)).words, ['old']);
    }
  });

  test('update return-copy failure preserves complete previous snapshot',
      () async {
    var calls = 0;
    var failAt = -1;
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) {
        if (++calls == failAt) throw StateError('copy failed');
        return value.copy(revision);
      },
    );
    final initial = await guarded.save(
      _Record(words: ['old']),
      precondition: const WritePrecondition.absent(),
    );
    final changed = initial.copy(initial.revision)..words[0] = 'changed';
    changed.updatedAt = initial.updatedAt.add(const Duration(seconds: 1));
    failAt = calls + 2;
    await expectLater(
      guarded.save(
        changed,
        precondition: WritePrecondition.atRevision(initial.revision),
      ),
      throwsStateError,
    );
    final observed = await guarded.getById(initial.id);
    expect(observed.words, ['old']);
    expect(observed.revision, initial.revision);
    expect(observed.createdAt, initial.createdAt);
    expect(observed.updatedAt, initial.updatedAt);
  });

  test('repository overflow and missing-key operations never mutate', () async {
    var copies = 0;
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) {
        copies++;
        return value.copy(revision);
      },
    );
    final maxed = _Record(words: [], revision: Revision(Revision.maxValue));
    await expectLater(
      guarded.save(
        maxed,
        precondition: WritePrecondition.atRevision(maxed.revision),
      ),
      throwsA(isA<RevisionCapacityException>()),
    );
    await expectLater(
      guarded.deleteById(
        maxed.id,
        precondition: WritePrecondition.atRevision(maxed.revision),
      ),
      throwsA(isA<RevisionCapacityException>()),
    );
    expect(copies, 0);
    final missing = maxed.copy(Revision(1));
    await expectLater(
      guarded.save(
        missing,
        precondition: WritePrecondition.atRevision(missing.revision),
      ),
      throwsA(isA<PreconditionFailedException>()),
    );
    await expectLater(
      guarded.deleteById(
        missing.id,
        precondition: WritePrecondition.atRevision(missing.revision),
      ),
      throwsA(isA<PreconditionFailedException>()),
    );
    await expectLater(
      guarded.getById(missing.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('trusted deep copier isolates nested lists and maps', () async {
    final guarded = InMemoryConditionalRepository<_Nested>(
      copyWithRevision: (value, revision) => value.copy(revision),
    );
    final proposed = _Nested(
      data: {
        'nested': [
          ['first'],
        ],
      },
    );
    final accepted = await guarded.save(
      proposed,
      precondition: const WritePrecondition.absent(),
    );
    proposed.data['nested']!.first[0] = 'proposal';
    accepted.data['nested']!.first.add('returned');
    final observed = await guarded.getById(proposed.id);
    expect(observed.data, {
      'nested': [
        ['first'],
      ],
    });
    observed.data['nested']!.clear();
    expect((await guarded.getById(proposed.id)).data, {
      'nested': [
        ['first'],
      ],
    });
  });
  test('copier may not return the same third instance for storage and caller',
      () async {
    final proposal = _Record(words: []);
    final reused = proposal.copy(Revision(1));
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (_, __) => reused,
    );
    await expectLater(
      guarded.save(
        proposal,
        precondition: const WritePrecondition.absent(),
      ),
      throwsA(isA<RepositoryCapabilityException>()),
    );
    await expectLater(
      guarded.getById(proposal.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('copier changing updatedAt is rejected', () async {
    final guarded = InMemoryConditionalRepository<_Record>(
      copyWithRevision: (value, revision) =>
          value.copy(revision)..updatedAt = DateTime.utc(1980),
    );
    final proposal = _Record(words: []);
    await expectLater(
      guarded.save(
        proposal,
        precondition: const WritePrecondition.absent(),
      ),
      throwsA(isA<RepositoryCapabilityException>()),
    );
    await expectLater(
      guarded.getById(proposal.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('rejected widened save preserves ordinary records', () async {
    final legacy = InMemoryRepository<AggregateRoot>();
    final ordinary = _Ordinary();
    await legacy.save(ordinary);
    await expectLater(
      legacy.save(_Record(words: [], id: ordinary.id)),
      throwsA(isA<RepositoryCapabilityException>()),
    );
    expect(await legacy.getById(ordinary.id), same(ordinary));
  });

  test('update and retirement compete atomically in both orders', () async {
    for (final deleteFirst in [false, true]) {
      final saved = await repository.save(
        _Record(words: ['old']),
        precondition: const WritePrecondition.absent(),
      );
      final condition = WritePrecondition.atRevision(saved.revision);
      Future<bool> update() async {
        try {
          await repository.save(
            saved.copy(saved.revision)..words[0] = 'new',
            precondition: condition,
          );
          return true;
        } on PreconditionFailedException {
          return false;
        }
      }

      Future<bool> retire() async {
        try {
          await repository.deleteById(saved.id, precondition: condition);
          return true;
        } on PreconditionFailedException {
          return false;
        }
      }

      final outcomes = await Future.wait(
        deleteFirst ? [retire(), update()] : [update(), retire()],
      );
      expect(outcomes, [true, false]);
      if (deleteFirst) {
        await expectLater(
          repository.getById(saved.id),
          throwsA(isA<RepositoryException>()),
        );
      } else {
        final observed = await repository.getById(saved.id);
        expect(observed.words, ['new']);
        expect(observed.revision, Revision(2));
      }
    }
  });

  test('failed missing-key update and delete do not reserve or retire a key',
      () async {
    final proposal = _Record(words: ['new']);
    final missing = proposal.copy(Revision(1));
    final condition = WritePrecondition.atRevision(missing.revision);
    await expectLater(
      repository.save(missing, precondition: condition),
      throwsA(isA<PreconditionFailedException>()),
    );
    await expectLater(
      repository.deleteById(missing.id, precondition: condition),
      throwsA(isA<PreconditionFailedException>()),
    );
    final saved = await repository.save(
      proposal,
      precondition: const WritePrecondition.absent(),
    );
    expect(saved.revision, Revision(1));
    expect((await repository.getById(saved.id)).words, ['new']);
  });
}

class _Nested extends VersionedAggregateRoot {
  _Nested({
    required this.data,
    super.id,
    super.createdAt,
    super.updatedAt,
    super.revision,
  });
  final Map<String, List<List<String>>> data;
  _Nested copy(Revision revision) => _Nested(
        data: {
          for (final entry in data.entries)
            entry.key: [
              for (final row in entry.value) [...row],
            ],
        },
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        revision: revision,
      );
}

class _Ordinary extends AggregateRoot {}
