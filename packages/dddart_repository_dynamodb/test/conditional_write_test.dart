@Tags(['requires-dynamodb'])
library;

import 'dart:async';
import 'dart:io';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

import 'package:test/test.dart';

import '../../dddart/test/support/conditional_aggregate_contract.dart';
import 'test_models.dart';

Future<
    (
      NativeIssueDynamoRepository,
      NativeIssueDynamoRepository,
      Future<void> Function()
    )> openNative({EventPublisher? publisher}) async {
  final a = DynamoConnection.local();
  final b = DynamoConnection.local();
  final table = 'conditional_${UuidValue.generate().uuid}';
  final first = NativeRepository(a, table, eventPublisher: publisher);
  await first.createTable();
  return (
    first,
    NativeRepository(b, table),
    () async {
      await a.client.deleteTable(tableName: table);
      a.dispose();
      b.dispose();
    }
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
        final a = DynamoConnection.local();
        final b = DynamoConnection.local();
        final table = 'conditional_${UuidValue.generate().uuid}';
        final first = ScopedRepository(a, table);
        await first.createTable();
        return (
          first,
          ScopedRepository(b, table),
          () async {
            await a.client.deleteTable(tableName: table);
            a.dispose();
            b.dispose();
          }
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
        final a = DynamoConnection.local();
        final b = DynamoConnection.local();
        final table = 'conditional_${UuidValue.generate().uuid}';
        final first = UserRepository(a, table);
        await first.createTable();
        return (
          first,
          UserRepository(b, table),
          () async {
            await a.client.deleteTable(tableName: table);
            a.dispose();
            b.dispose();
          }
        );
      },
      create: (value, id) =>
          TestUser(id: id, name: '$value', email: 'a@example.com'),
      value: (aggregate) => int.parse(aggregate.name),
    );
  });

  group('document commit and publication', () {
    late NativeIssueDynamoRepository first;
    late NativeIssueDynamoRepository second;
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
        NativeIssueDynamoRepository repository,
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
  test(
      'lost response after real persistence is uncertain and does not publish or retry',
      () async {
    final direct = DynamoConnection.local();
    addTearDown(direct.dispose);
    final table = 'conditional_${UuidValue.generate().uuid}';
    final observer = NativeRepository(direct, table);
    await observer.createTable();
    addTearDown(() => direct.client.deleteTable(tableName: table));
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await proxy.close(force: true);
    });
    var writes = 0;
    final dispatched = Completer<void>();
    proxy.listen((request) async {
      final forwarded = await http.postUrl(Uri.parse('http://localhost:8000/'));
      request.headers.forEach((name, values) {
        if (name != 'host' && name != 'content-length') {
          forwarded.headers.set(name, values);
        }
      });
      await forwarded.addStream(request);
      final response = await forwarded.close();
      await response.drain<void>();
      writes++;
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      dispatched.complete();
    });
    final failing = DynamoConnection(
      region: 'us-east-1',
      endpoint: 'http://127.0.0.1:${proxy.port}',
      credentials: AwsClientCredentials(accessKey: 'dummy', secretKey: 'dummy'),
    );
    addTearDown(failing.dispose);
    final publisher = RecordingPublisher();
    final repository =
        NativeRepository(failing, table, eventPublisher: publisher);
    final aggregate = item(5, null)
      ..raiseEvent(Changed(const NativeId('event')));
    await expectLater(
      repository.saveConditional(
        aggregate,
        expected: const ExpectedRevision.absent(),
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
    await dispatched.future;
    expect(writes, 1);
    expect((await observer.getVersioned(aggregate.id)).aggregate.label, '5');
    expect(publisher.events, isEmpty);
    expect(aggregate.getUncommittedEvents(), hasLength(1));
  });
}

class Changed extends DomainEvent<NativeId> {
  Changed(NativeId id) : super(aggregateId: id);
}

class RecordingPublisher implements EventPublisher {
  final events = <DomainEvent<Identity>>[];
  @override
  Future<bool> publish(DomainEvent<Identity> event) async {
    events.add(event);
    return true;
  }
}

class NativeRepository extends NativeIssueDynamoRepository {
  NativeRepository(super.connection, this.tableName, {super.eventPublisher})
      : super(identityCodecs: identityCodecs());
  @override
  final String tableName;
}

class ScopedRepository extends ScopedIssueDynamoRepositoryImpl {
  ScopedRepository(super.connection, this.tableName)
      : super(identityCodecs: identityCodecs());
  @override
  final String tableName;
}

class UserRepository extends TestUserDynamoRepository {
  UserRepository(super.connection, this.tableName);
  @override
  final String tableName;
}
