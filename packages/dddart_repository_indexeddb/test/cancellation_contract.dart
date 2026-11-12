import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:dddart_repository_indexeddb/src/transaction_error_guard_stub.dart'
    if (dart.library.js_interop) 'package:dddart_repository_indexeddb/src/transaction_error_guard_web.dart'
    as native_guard;
import 'package:idb_shim/idb.dart';
import 'package:test/test.dart';

class _Sample extends UuidAggregateRoot {
  _Sample(this.name, {super.id});

  final String name;
}

// Gates opening/acknowledgment, never inserts an await between native requests.
// The actual transaction still commits or aborts in the supplied real factory.
class _Control {
  final started = Completer<void>();
  final settled = Completer<void>();
  final release = Completer<void>();
  void Function()? atReceipt;
  bool failReceipt = false;
  bool loseAck = false;
}

class _Factory implements IdbFactory {
  _Factory(this.delegate);

  final IdbFactory delegate;
  Completer<void>? openGate;
  final openStarted = Completer<void>();
  _Control? nextWrite;
  int opens = 0;
  int transactions = 0;
  int closes = 0;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    opens++;
    if (!openStarted.isCompleted) openStarted.complete();
    await openGate?.future;
    return _Database(
      this,
      await delegate.open(
        dbName,
        version: version,
        onUpgradeNeeded: onUpgradeNeeded,
        onBlocked: onBlocked,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Database extends Database {
  _Database(_Factory super.factory, this.delegate);

  final Database delegate;

  @override
  Transaction transaction(Object storeNameOrStoreNames, String mode) {
    final controlFactory = factory as _Factory;
    controlFactory.transactions++;
    final transaction = delegate.transaction(storeNameOrStoreNames, mode);
    final control = mode == idbModeReadWrite ? controlFactory.nextWrite : null;
    if (control == null) return transaction;
    controlFactory.nextWrite = null;
    control.started.complete();
    return _Transaction(transaction, control);
  }

  @override
  void close() {
    (factory as _Factory).closes++;
    delegate.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Transaction implements Transaction {
  _Transaction(this.delegate, this.control);

  final Transaction delegate;
  final _Control control;

  @override
  Future<Database> get completed async {
    final completion = delegate.completed;
    native_guard.guardNativeTransactionError(delegate);
    // Observe real completion immediately, even while acknowledgment is held.
    final failure = await completion.then<AsyncError?>(
      (_) => null,
      onError: (Object error, StackTrace stack) => AsyncError(error, stack),
    );
    control.settled.complete();
    await control.release.future;
    if (control.loseAck) {
      // A typed late error must also be consumed by the losing race branch.
      throw const RepositoryException('late acknowledgment failure',
          type: RepositoryExceptionType.connection);
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return delegate.database;
  }

  @override
  ObjectStore objectStore(String name) =>
      _Store(delegate.objectStore(name), control);

  @override
  void abort() => delegate.abort();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Store implements ObjectStore {
  _Store(this.delegate, this.control);

  final ObjectStore delegate;
  final _Control control;

  @override
  Future<Object?> getObject(Object key) => delegate.getObject(key);

  @override
  Future<Object> put(Object value, [Object? key]) {
    if (key is String && key.startsWith('__dddart_receipt__')) {
      control.atReceipt?.call();
      if (control.failReceipt) {
        return Future.error(StateError('late receipt setup failure'));
      }
    }
    return delegate.put(value, key);
  }

  @override
  Future<void> delete(Object keyOrRange) => delegate.delete(keyOrRange);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

IndexedDbRepository<_Sample, UuidValue> _repository(
        IdbFactory factory, String name) =>
    IndexedDbRepository<_Sample, UuidValue>(
      factory: factory,
      databaseName: name,
      storeName: 'samples',
      encode: (sample) =>
          jsonEncode({'id': sample.id.uuid, 'name': sample.name}),
      decode: (payload) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        return _Sample(data['name'] as String,
            id: UuidValue.fromString(data['id'] as String));
      },
    );

ConditionalCommit<_Sample, UuidValue> _put(
        _Sample sample, ExpectedRevision expected, String claim) =>
    ConditionalCommit(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(sample,
            expected: expected, uniqueValues: [UniqueValue('name', claim)]),
      ],
    );

final _notFound = throwsA(isA<RepositoryException>().having(
  (error) => error.type,
  'type',
  RepositoryExceptionType.notFound,
));
final _closed = throwsA(isA<RepositoryException>().having(
  (error) => error.type,
  'type',
  RepositoryExceptionType.connection,
));

Future<Map<String, Object?>> _raw(
    IdbFactory factory, String name, List<Database> connections) async {
  final db = await factory.open(name, version: 2);
  // The memory factory shares connection handles. Keep inspection handles
  // until teardown rather than accidentally closing the repository's handle.
  connections.add(db);
  final transaction = db.transaction('samples', idbModeReadOnly);
  final completed = transaction.completed;
  final records = <String, Object?>{};
  await for (final cursor
      in transaction.objectStore('samples').openCursor(autoAdvance: true)) {
    records[cursor.primaryKey as String] = cursor.value;
  }
  await completed;
  return records;
}

/// Same deterministic lifecycle contract against memory and native IndexedDB.
void cancellationContract(IdbFactory Function() createFactory,
    {bool native = false}) {
  final inspections = <Database>[];
  late IdbFactory storage;
  late _Factory factory;
  late String name;
  late IndexedDbRepository<_Sample, UuidValue> repository;
  late _Sample prior;
  late _Sample basic;
  late _Sample added;
  late ConditionalCommit<_Sample, UuidValue> request;
  late Map<String, Object?> baseline;

  setUp(() async {
    storage = createFactory();
    factory = _Factory(storage);
    name = 'dddart-cancellation-${UuidValue.generate()}';
    repository = _repository(factory, name);
    prior = _Sample('Prior');
    basic = _Sample('Unrelated');
    added = _Sample('Added');
    await repository.save(basic);
    final created = await repository.commitConditional(
        _put(prior, const ExpectedRevision.absent(), 'prior'));
    request = ConditionalCommit(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(_Sample('Changed', id: prior.id),
            expected: ExpectedRevision.match(created.revisions[prior.id]!),
            uniqueValues: const [UniqueValue('name', 'changed')]),
        ConditionalMutation.put(added,
            expected: const ExpectedRevision.absent(),
            uniqueValues: const [UniqueValue('name', 'added')]),
      ],
    );
    baseline = await _raw(storage, name, inspections);
  });

  tearDown(() async {
    await repository.close();
    for (final connection in inspections) {
      connection.close();
    }
    inspections.clear();
    await storage.deleteDatabase(name);
  });

  Future<void> verifyCommitted(CommitResult<UuidValue> result) async {
    expect(result.decision, CommitDecision.committed);
    expect(result.operationId, request.operationId);
    expect(result.payloadDigest, repository.digestFor(request));
    expect((await repository.getById(basic.id)).name, 'Unrelated');
    for (final sample in [_Sample('Changed', id: prior.id), added]) {
      final version = await repository.getVersioned(sample.id);
      expect(version.aggregate.name, sample.name);
      expect(version.revision, result.revisions[sample.id]);
      expect(
          (await repository
                  .findUnique(UniqueValue('name', sample.name.toLowerCase())))
              .revision,
          version.revision);
    }
    await expectLater(
        repository.findUnique(const UniqueValue('name', 'prior')), _notFound);
    final raw = await _raw(storage, name, inspections);
    expect(raw.length, 9); // schema, 3 aggregates, 2 claims, 2 receipts, count
    expect(
        raw['__dddart_receipt_count__'], {'kind': 'receiptCount', 'count': 2});
    final receipt = raw['__dddart_receipt__${request.operationId.uuid}'] as Map;
    expect(receipt['digest'], result.payloadDigest);
    expect(receipt['decision'], 'committed');
    expect(receipt['revisions'], {
      for (final entry in result.revisions.entries) entry.key.uuid: entry.value,
    });
    // Exact retry returns the same receipt, does not generate new revisions,
    // increment the count, or recreate the released unique claim.
    final retry = await repository.commitConditional(request);
    expect(retry.revisions, result.revisions);
    expect(await _raw(storage, name, inspections), raw);
  }

  test('already cancelled call performs no open or dispatch', () async {
    final freshFactory = _Factory(storage);
    final fresh = _repository(freshFactory, name);
    final cancellation = IndexedDbCancellation()..cancel();
    cancellation.cancel(); // idempotent
    await expectLater(
      fresh.commitConditional(request, cancellation: cancellation),
      throwsA(isA<IndexedDbOperationCancelled>()
          .having((error) => error.operationId, 'id', request.operationId)
          .having((error) => error.payloadDigest, 'digest',
              fresh.digestFor(request))),
    );
    expect(freshFactory.opens, 0);
    expect(freshFactory.transactions, 0);
    expect(await _raw(storage, name, inspections), baseline);
    await fresh.close();
  });

  test('cancellation during opening prevents transaction dispatch', () async {
    final openingFactory = _Factory(storage)..openGate = Completer<void>();
    final fresh = _repository(openingFactory, name);
    final cancellation = IndexedDbCancellation();
    final pending =
        fresh.commitConditional(request, cancellation: cancellation);
    final observed =
        expectLater(pending, throwsA(isA<IndexedDbOperationCancelled>()));
    await openingFactory.openStarted.future;
    cancellation.cancel();
    openingFactory.openGate!.complete();
    await observed;
    expect(openingFactory.transactions, 1); // schema validation only
    expect(await _raw(storage, name, inspections), baseline);
    await fresh.close();
  });

  test('close while opening blocks every operation from dispatching', () async {
    final openingFactory = _Factory(storage)..openGate = Completer<void>();
    final fresh = _repository(openingFactory, name);
    final observed = <Future<void>>[
      expectLater(fresh.save(_Sample('Cannot save')), _closed),
      expectLater(fresh.deleteById(basic.id), _closed),
      expectLater(fresh.getById(basic.id), _closed),
      expectLater(fresh.getVersioned(prior.id), _closed),
      expectLater(
          fresh.findUnique(const UniqueValue('name', 'prior')), _closed),
      expectLater(fresh.commitConditional(request), _closed),
    ];
    final resolving =
        fresh.resolveOperation(request.operationId, fresh.digestFor(request));
    await openingFactory.openStarted.future;
    final closing = fresh.close();
    openingFactory.openGate!.complete();
    await Future.wait(observed);
    expect((await resolving).decision, CommitDecision.uncertain);
    await closing;
    expect(openingFactory.transactions, 1); // only the opening schema read
    expect(openingFactory.closes, 1);
    await fresh.close();
    expect(openingFactory.closes, 1);
    expect(await _raw(storage, name, inspections), baseline);
  });

  for (final cancelAfterCommit in [false, true]) {
    test(
        'cancellation wins ${cancelAfterCommit ? 'after' : 'before'} real commit',
        () async {
      final cancellation = IndexedDbCancellation();
      final control = _Control();
      if (!cancelAfterCommit) control.atReceipt = cancellation.cancel;
      factory.nextWrite = control;
      final pending =
          repository.commitConditional(request, cancellation: cancellation);
      if (cancelAfterCommit) {
        await control
            .settled.future; // persisted, acknowledgment still withheld
        cancellation.cancel();
      }
      final result = await pending;
      expect(result.decision, CommitDecision.uncertain);
      expect(result.operationId, request.operationId);
      expect(result.payloadDigest, repository.digestFor(request));
      expect(result.revisions, isEmpty);
      expect(result.rejection, isNull);
      control.release.complete();
      await control.settled.future;
      final resolved = await repository.resolveOperation(
          result.operationId, result.payloadDigest);
      await verifyCommitted(resolved);
    });
  }

  test('confirmed completion wins a subsequent cancellation', () async {
    final cancellation = IndexedDbCancellation();
    final control = _Control();
    factory.nextWrite = control;
    final pending =
        repository.commitConditional(request, cancellation: cancellation);
    await control.settled.future;
    control.release.complete();
    final result = await pending;
    cancellation.cancel();
    await verifyCommitted(result);
  });

  test('independent timeout stops waiting, not the dispatched transaction',
      () async {
    final control = _Control();
    factory.nextWrite = control;
    final pending = repository.commitConditional(request);
    await control.started.future;
    final digest = repository.digestFor(request);
    final timedOut = await pending.timeout(Duration.zero,
        onTimeout: () => CommitResult(
            operationId: request.operationId,
            payloadDigest: digest,
            decision: CommitDecision.uncertain));
    expect(timedOut.decision, CommitDecision.uncertain);
    control.release.complete();
    await verifyCommitted(await pending);
  });

  test('close after dispatch does not abort or drain an active transaction',
      () async {
    final control = _Control();
    factory.nextWrite = control;
    final pending = repository.commitConditional(request);
    await control.started.future;
    await repository.close(); // returns while acknowledgment remains held
    await expectLater(repository.commitConditional(request), _closed);
    control.release.complete();
    final result = await pending;
    repository = _repository(storage, name);
    await verifyCommitted(result);
  }, skip: native ? false : 'Memory factory closes shared handles immediately');

  for (final deleting in [false, true]) {
    test(
        'close after basic ${deleting ? 'delete' : 'save'} dispatch drains natively',
        () async {
      final control = _Control();
      factory.nextWrite = control;
      final pending = deleting
          ? repository.deleteById(basic.id)
          : repository.save(_Sample('Updated basic', id: basic.id));
      await control.started.future;
      await repository.close();
      control.release.complete();
      await pending;
      repository = _repository(storage, name);
      if (deleting) {
        await expectLater(repository.getById(basic.id), _notFound);
      } else {
        expect((await repository.getById(basic.id)).name, 'Updated basic');
      }
      expect((await repository.getVersioned(prior.id)).aggregate.name, 'Prior');
      final raw = await _raw(storage, name, inspections);
      baseline.remove(basic.id.uuid);
      raw.remove(basic.id.uuid);
      expect(raw, baseline); // all conditional claims and receipts untouched
    },
        skip: native
            ? false
            : 'Memory factory closes shared handles immediately');
  }

  for (final abort in [false, true]) {
    test('cancelled waiter observes late ${abort ? 'abort' : 'typed error'}',
        () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final cancellation = IndexedDbCancellation();
        final control = _Control()
          ..atReceipt = cancellation.cancel
          ..failReceipt = abort
          ..loseAck = !abort;
        factory.nextWrite = control;
        final result = await repository.commitConditional(request,
            cancellation: cancellation);
        expect(result.decision, CommitDecision.uncertain);
        control.release.complete();
        await control.settled.future;
        // Allow losing-branch completion/error callbacks to run in this zone.
        await Future<void>.delayed(Duration.zero);
        if (abort) {
          expect(await _raw(storage, name, inspections), baseline);
          final resolved = await repository.resolveOperation(
              result.operationId, result.payloadDigest);
          expect(resolved.decision, CommitDecision.uncertain);
          await verifyCommitted(await repository.commitConditional(request));
        } else {
          await verifyCommitted(await repository.resolveOperation(
              result.operationId, result.payloadDigest));
        }
      }, (error, _) => uncaught.add(error));
      expect(uncaught, isEmpty);
    });
  }
}
