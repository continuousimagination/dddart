@Tags(['requires-mongo'])
library;

import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

import '../../dddart/test/support/conditional_aggregate_contract.dart';
import 'test_models.dart';

Future<(Db, Db, Future<void> Function())> openDatabases() async {
  final name = 'conditional_${UuidValue.generate().uuid.replaceAll('-', '')}';
  final a = Db('mongodb://127.0.0.1:27017/$name');
  final b = Db('mongodb://127.0.0.1:27017/$name');
  await a.open();
  await b.open();
  await a.runCommand({
    'create': 'fixture_native_identities',
    'collation': {'locale': 'en', 'strength': 2},
  });
  return (
    a,
    b,
    () async {
      await a.drop();
      await a.close();
      await b.close();
    }
  );
}

Future<
    (
      NativeIssueMongoRepository,
      NativeIssueMongoRepository,
      Future<void> Function()
    )> openNative({EventPublisher? publisher}) async {
  final (a, b, close) = await openDatabases();
  return (
    NativeIssueMongoRepository(
      a,
      identityCodecs: identityCodecs(),
      eventPublisher: publisher,
    ),
    NativeIssueMongoRepository(b, identityCodecs: identityCodecs()),
    close
  );
}

NativeIssue item(int value, NativeId? id) => NativeIssue(
      id: id ?? NativeId(UuidValue.generate().uuid),
      label: '$value',
    );

void main() {
  group('native identity', () {
    conditionalAggregateContract<NativeIssue, NativeId>(
      open: () async {
        final fixture = await openNative();
        return (fixture.$1, fixture.$2, fixture.$3);
      },
      create: item,
      value: (aggregate) => int.parse(aggregate.label),
    );
  });
  group('scoped identity and custom interface', () {
    conditionalAggregateContract<ScopedIssue, ScopedId>(
      open: () async {
        final (a, b, close) = await openDatabases();
        return (
          ScopedIssueMongoRepositoryImpl(a, identityCodecs: identityCodecs()),
          ScopedIssueMongoRepositoryImpl(b, identityCodecs: identityCodecs()),
          close
        );
      },
      create: (value, id) => ScopedIssue(
        id: id ?? ScopedId(UuidValue.generate().uuid, 7),
        label: '$value',
      ),
      value: (aggregate) => int.parse(aggregate.label),
    );
  });
  group('UUID identity', () {
    conditionalAggregateContract<TestUser, UuidValue>(
      open: () async {
        final (a, b, close) = await openDatabases();
        return (TestUserMongoRepository(a), TestUserMongoRepository(b), close);
      },
      create: (value, id) =>
          TestUser(id: id, name: '$value', email: 'a@example.com'),
      value: (aggregate) => int.parse(aggregate.name),
    );
  });

  group('document commit and publication', () {
    late NativeIssueMongoRepository first;
    late NativeIssueMongoRepository second;
    late RecordingPublisher publisher;
    setUp(() async {
      publisher = RecordingPublisher();
      final fixture = await openNative(publisher: publisher);
      first = fixture.$1;
      second = fixture.$2;
      addTearDown(fixture.$3);
    });

    test('concurrent create-if-absent never upserts a competing record',
        () async {
      final original = item(0, null);
      Future<Object> create(
        NativeIssueMongoRepository repository,
        int value,
      ) async {
        try {
          return await repository.saveConditional(
            item(value, original.id),
            expected: const ExpectedRevision.absent(),
          );
        } on RevisionConflictException<NativeId> catch (error) {
          return error;
        }
      }

      final results = await Future.wait([create(first, 1), create(second, 2)]);
      expect(results.whereType<String>(), hasLength(1));
      expect(
        results.whereType<RevisionConflictException<NativeId>>(),
        hasLength(1),
      );
      final actual = await first.getVersioned(original.id);
      expect(actual.revision, results.whereType<String>().single);
      expect(actual.aggregate.label, results.first is String ? '1' : '2');
    });

    test(
        'conflicts preserve pending events and publication follows confirmation',
        () async {
      final original = item(0, null);
      final token = await first.saveConditional(
        original,
        expected: const ExpectedRevision.absent(),
      );
      await second.save(item(1, original.id));
      final stale = item(2, original.id)..raiseEvent(Changed(original.id));
      await expectLater(
        first.saveConditional(stale, expected: ExpectedRevision.match(token)),
        throwsA(
          isA<RevisionConflictException<NativeId>>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.conflict,
          ),
        ),
      );
      expect(publisher.events, isEmpty);
      expect(stale.getUncommittedEvents(), hasLength(1));
      final current = await first.getVersioned(original.id);
      await first.saveConditional(
        stale,
        expected: ExpectedRevision.match(current.revision),
      );
      expect(publisher.events, hasLength(1));
      expect(stale.getUncommittedEvents(), isEmpty);
    });

    test('every versioned read pairs a committed payload and its own token',
        () async {
      final original = item(0, null);
      var token = await first.saveConditional(
        original,
        expected: const ExpectedRevision.absent(),
      );
      final committed = <String, String>{token: '0'};
      final reads = <VersionedAggregate<NativeIssue, NativeId>>[];
      await Future.wait([
        () async {
          for (var value = 1; value <= 20; value++) {
            token = await first.saveConditional(
              item(value, original.id),
              expected: ExpectedRevision.match(token),
            );
            committed[token] = '$value';
          }
        }(),
        () async {
          for (var value = 0; value < 40; value++) {
            reads.add(await second.getVersioned(original.id));
          }
        }(),
      ]);
      for (final snapshot in reads) {
        expect(snapshot.aggregate.label, committed[snapshot.revision]);
      }
    });

    test(
        'revision equality is exact even with case-insensitive collection defaults',
        () async {
      final original = item(0, null);
      await first.save(original);
      final before = await first.getVersioned(original.id);
      final different = before.revision.toUpperCase();
      expect(different, isNot(before.revision));
      await expectLater(
        first.saveConditional(
          item(2, original.id),
          expected: ExpectedRevision.match(different),
        ),
        throwsA(isA<RevisionConflictException<NativeId>>()),
      );
      expect(
        (await second.getVersioned(original.id)).revision,
        before.revision,
      );
    });
  });
  test('unrelated unique indexes remain duplicate errors and publish nothing',
      () async {
    final (a, b, close) = await openDatabases();
    addTearDown(close);
    await a
        .collection('fixture_native_identities')
        .createIndex(keys: {'label': 1}, unique: true);
    final publisher = RecordingPublisher();
    final repository = NativeIssueMongoRepository(
      a,
      identityCodecs: identityCodecs(),
      eventPublisher: publisher,
    );
    await repository.save(item(1, null));
    final duplicate = item(1, null)
      ..raiseEvent(Changed(const NativeId('event')));
    await expectLater(
      repository.saveConditional(
        duplicate,
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(
        isA<RepositoryException>()
            .having((e) => e.type, 'type', RepositoryExceptionType.duplicate),
      ),
    );
    expect(publisher.events, isEmpty);
    expect(duplicate.getUncommittedEvents(), hasLength(1));
  });
  test(
      'server validation rejection preserves the old document and pending events',
      () async {
    final (a, b, close) = await openDatabases();
    addTearDown(close);
    await a.runCommand({
      'collMod': 'fixture_native_identities',
      'validator': {
        'label': {r'$ne': '99'},
      },
    });
    final publisher = RecordingPublisher();
    final repository = NativeIssueMongoRepository(
      a,
      identityCodecs: identityCodecs(),
      eventPublisher: publisher,
    );
    final original = item(0, null);
    await repository.save(original);
    final before = await repository.getVersioned(original.id);
    final rejected = item(99, original.id)..raiseEvent(Changed(original.id));
    await expectLater(
      repository.saveConditional(
        rejected,
        expected: ExpectedRevision.match(before.revision),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryExceptionType.constraint,
        ),
      ),
    );
    expect(
      (await repository.getVersioned(original.id)).revision,
      before.revision,
    );
    expect(publisher.events, isEmpty);
    expect(rejected.getUncommittedEvents(), hasLength(1));
  });
}

class Changed extends DomainEvent<NativeId, UuidValue> {
  Changed(NativeId id) : super(eventId: UuidValue.generate(), aggregateId: id);
}

class RecordingPublisher implements EventPublisher {
  final events = <DomainEvent<Identity, Identity>>[];
  @override
  Future<bool> publish(DomainEvent<Identity, Identity> event) async {
    events.add(event);
    return true;
  }
}
