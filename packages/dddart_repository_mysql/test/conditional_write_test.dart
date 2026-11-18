@Tags(['requires-mysql'])
library;

import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

import '../../dddart/test/support/conditional_aggregate_contract.dart';
import 'integration_test_models.dart';
import 'test_helpers.dart';

Future<(MysqlConnection, MysqlConnection, Future<void> Function())>
    openConnections() async {
  final settings = TestMysqlHelper();
  final admin = await settings.connect();
  final database = 'cas_${UuidValue.generate().uuid.replaceAll('-', '')}';
  await admin.execute('CREATE DATABASE $database');
  MysqlConnection connection() => MysqlConnection(
        host: settings.host,
        port: settings.port,
        database: database,
        user: settings.user,
        password: settings.password,
      );
  final a = connection();
  final b = connection();
  await a.open();
  await b.open();
  return (
    a,
    b,
    () async {
      await a.close();
      await b.close();
      await admin.execute('DROP DATABASE $database');
      await settings.disconnect();
    }
  );
}

NativeIssue native(int value, NativeId? id) {
  final key = id ?? NativeId(UuidValue.generate().uuid);
  return NativeIssue(
    id: key,
    label: '$value',
    reference: const NativeId('reference/%, café'),
    comments: [
      NativeComment(
        id: ScopedId(key.value, 1),
        authorId: const NativeId('author'),
        message: '$value',
      ),
    ],
  );
}

void main() {
  group('native identity and complete graph', () {
    conditionalAggregateContract<NativeIssue, NativeId>(
      open: () async {
        final (a, b, close) = await openConnections();
        final first =
            NativeIssueMysqlRepositoryImpl(a, identityCodecs: identityCodecs());
        await first.createTables();
        return (
          first,
          NativeIssueMysqlRepositoryImpl(b, identityCodecs: identityCodecs()),
          close
        );
      },
      create: native,
      value: (item) {
        expect(item.comments.single.message, item.label);
        return int.parse(item.label);
      },
    );
  });
  group('scoped identity', () {
    conditionalAggregateContract<ScopedIssue, ScopedId>(
      open: () async {
        final (a, b, close) = await openConnections();
        final first =
            ScopedIssueMysqlRepository(a, identityCodecs: identityCodecs());
        await first.createTables();
        return (
          first,
          ScopedIssueMysqlRepository(b, identityCodecs: identityCodecs()),
          close
        );
      },
      create: (value, id) => ScopedIssue(
        id: id ?? ScopedId(UuidValue.generate().uuid, 7),
        label: '$value',
        reference: const ScopedId('reference', 1),
      ),
      value: (item) => int.parse(item.label),
    );
  });
  group('UUID identity', () {
    conditionalAggregateContract<SimpleProduct, UuidValue>(
      open: () async {
        final (a, b, close) = await openConnections();
        final first = SimpleProductMysqlRepository(a);
        await first.createTables();
        return (first, SimpleProductMysqlRepository(b), close);
      },
      create: (value, id) => SimpleProduct(id: id, name: '$value', price: 1),
      value: (item) => int.parse(item.name),
    );
  });

  group('SQL graph commit and publication', () {
    late MysqlConnection a;
    late MysqlConnection b;
    late NativeIssueMysqlRepositoryImpl first;
    late NativeIssueMysqlRepositoryImpl second;
    late RecordingPublisher publisher;
    setUp(() async {
      final opened = await openConnections();
      a = opened.$1;
      b = opened.$2;
      addTearDown(opened.$3);
      publisher = RecordingPublisher();
      first = NativeIssueMysqlRepositoryImpl(
        a,
        identityCodecs: identityCodecs(),
        eventPublisher: publisher,
      );
      second =
          NativeIssueMysqlRepositoryImpl(b, identityCodecs: identityCodecs());
      await first.createTables();
    });

    test('two absent writers create only one graph', () async {
      final item = native(0, null);
      Future<Object> create(
        NativeIssueMysqlRepositoryImpl repository,
        int value,
      ) async {
        try {
          return await repository.saveConditional(
            native(value, item.id),
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
      final current = await first.getVersioned(item.id);
      expect(current.revision, results.whereType<String>().single);
      expect(
        current.aggregate.comments.single.message,
        current.aggregate.label,
      );
    });

    test('failed child write rolls back root, revision and complete graph',
        () async {
      final item = native(0, null);
      await first.save(item);
      final before = await first.getVersioned(item.id);
      await a.execute(
        "CREATE TRIGGER fail_child BEFORE INSERT ON native_comment FOR EACH ROW BEGIN IF NEW.message = '99' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'injected child failure'; END IF; END",
      );
      final proposed = native(99, item.id)..raiseEvent(Changed(item.id));
      await expectLater(
        first.saveConditional(
          proposed,
          expected: ExpectedRevision.match(before.revision),
        ),
        throwsA(isA<RepositoryException>()),
      );
      final after = await second.getVersioned(item.id);
      expect(after.revision, before.revision);
      expect(after.aggregate.label, '0');
      expect(after.aggregate.comments.single.message, '0');
      expect(publisher.events, isEmpty);
      expect(proposed.getUncommittedEvents(), hasLength(1));
    });

    test('a stale writer leaves its pending event and the winning graph intact',
        () async {
      final item = native(0, null);
      await first.save(item);
      final before = await first.getVersioned(item.id);
      await second.save(native(1, item.id));
      final stale = native(2, item.id)..raiseEvent(Changed(item.id));
      await expectLater(
        first.saveConditional(
          stale,
          expected: ExpectedRevision.match(before.revision),
        ),
        throwsA(isA<RevisionConflictException<NativeId>>()),
      );
      expect(publisher.events, isEmpty);
      expect(stale.getUncommittedEvents(), hasLength(1));
      expect((await second.getById(item.id)).comments.single.message, '1');
    });

    test(
        'nested rollback retains events; commit publishes after releasing locks',
        () async {
      final item = native(0, null)
        ..raiseEvent(Changed(const NativeId('event')));
      await expectLater(
        a.transaction(() async {
          await first.save(item);
          expect(publisher.events, isEmpty);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(item.getUncommittedEvents(), hasLength(1));
      expect(publisher.events, isEmpty);
      publisher.onPublish = () async {
        expect((await second.getById(item.id)).label, '0');
      };
      await a.transaction(() async {
        await first.save(item);
        expect(publisher.events, isEmpty);
      });
      expect(publisher.events, hasLength(1));
      expect(item.getUncommittedEvents(), isEmpty);
    });

    test('versioned reader cannot observe an uncommitted graph or revision',
        () async {
      final item = native(0, null);
      await first.save(item);
      final old = await second.getVersioned(item.id);
      final entered = Completer<void>();
      final release = Completer<void>();
      final writing = a.transaction(() async {
        await first.save(native(1, item.id));
        entered.complete();
        await release.future;
      });
      await entered.future;
      var completed = false;
      final reading = second.getVersioned(item.id).then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);
      release.complete();
      await writing;
      final snapshot = await reading;
      expect(snapshot.revision, isNot(old.revision));
      expect(snapshot.aggregate.label, '1');
      expect(snapshot.aggregate.comments.single.message, '1');
      expect(old.aggregate.comments.single.message, '0');
    });

    test('conditional writes reject nesting before touching storage', () async {
      final item = native(0, null);
      await a.transaction(() async {
        await expectLater(
          first.saveConditional(
            item,
            expected: const ExpectedRevision.absent(),
          ),
          throwsStateError,
        );
      });
      await expectLater(
        first.getById(item.id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    });
  });
}

class Changed extends DomainEvent<NativeId, UuidValue> {
  Changed(NativeId id) : super(eventId: UuidValue.generate(), aggregateId: id);
}

class RecordingPublisher implements EventPublisher {
  final events = <DomainEvent<Identity, Identity>>[];
  Future<void> Function()? onPublish;
  @override
  Future<bool> publish(DomainEvent<Identity, Identity> event) async {
    await onPublish?.call();
    events.add(event);
    return true;
  }
}
