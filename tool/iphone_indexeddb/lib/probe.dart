import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb.dart';

typedef Repository = IndexedDbRepository<Sample, UuidValue>;
const testedSha = '62af23ffa369c2d2cba13c93e39eee4c90c2325d';

class Sample extends UuidAggregateRoot {
  Sample(this.label, {super.id});
  final String label;
}

String encode(Sample value) =>
    jsonEncode({'id': value.id.uuid, 'label': value.label});
Sample decode(String value) {
  final data = jsonDecode(value) as Map<String, dynamic>;
  return Sample(
    data['label'] as String,
    id: UuidValue.fromString(data['id'] as String),
  );
}

/// The manifest is held outside the adapter database. Verification only reads;
/// it never reseeds missing records or repairs a failed lifecycle observation.
class Probe {
  Probe(this.factory, this.state, this.save, this.log);
  final IdbFactory factory;
  final Map<String, dynamic> state;
  final void Function() save;
  final void Function(String, String) log;
  String get prefix => 'dddart-77-${state['runId']}';
  List<dynamic> get receipts => state['receipts'] as List<dynamic>;
  UuidValue id(String key) => UuidValue.fromString(state[key] as String);

  Repository repository(String suffix, {IdbFactory? using, int codec = 1}) =>
      Repository(
        factory: using ?? factory,
        databaseName: '$prefix-$suffix',
        storeName: 'samples',
        codecVersion: codec,
        encode: encode,
        decode: decode,
      );

  void check(bool value, String message) {
    if (!value) throw StateError(message);
    log('pass', message);
  }

  Future<void> error(
    Future<dynamic> Function() action,
    RepositoryExceptionType type,
    String message,
  ) async {
    try {
      await action();
    } on RepositoryException catch (e) {
      check(e.type == type, '$message (typed ${type.name})');
      return;
    }
    throw StateError('$message: operation unexpectedly succeeded');
  }

  ConditionalMutation<Sample, UuidValue> put(
    Sample sample, {
    String? revision,
    String? unique,
  }) => ConditionalMutation.put(
    sample,
    expected: revision == null
        ? const ExpectedRevision.absent()
        : ExpectedRevision.match(revision),
    uniqueValues: unique == null ? [] : [UniqueValue('label', unique)],
  );

  ConditionalCommit<Sample, UuidValue> request(
    List<ConditionalMutation<Sample, UuidValue>> changes, {
    UuidValue? operation,
  }) => ConditionalCommit(
    operationId: operation ?? UuidValue.generate(),
    mutations: changes,
  );

  void remember(CommitResult<UuidValue> result, {String suffix = 'main'}) {
    receipts.add({
      'database': suffix,
      'operationId': result.operationId.uuid,
      'digest': result.payloadDigest,
      'decision': result.decision.name,
      'rejection': result.rejection?.name,
      'revisions': result.revisions.map(
        (id, revision) => MapEntry(id.uuid, revision),
      ),
    });
    save();
  }

  Future<void> baseline() async {
    if (state['baselineStarted'] == true) {
      throw StateError(
        'This run was already started. Export it before starting a new run.',
      );
    }
    state['baselineStarted'] = true;
    state['receipts'] = <dynamic>[];
    for (final key in ['crud', 'deleted', 'a', 'b', 'collision', 'aba']) {
      state[key] = UuidValue.generate().uuid;
    }
    save();
    final repo = repository('main');
    try {
      await repo.save(Sample('created', id: id('crud')));
      check(
        (await repo.getById(id('crud'))).label == 'created',
        'CRUD create/read',
      );
      await repo.save(Sample('updated', id: id('crud')));
      check((await repo.getById(id('crud'))).label == 'updated', 'CRUD update');
      await repo.save(Sample('delete me', id: id('deleted')));
      await repo.deleteById(id('deleted'));
      await error(
        () => repo.getById(id('deleted')),
        RepositoryExceptionType.notFound,
        'CRUD delete',
      );

      final created = await repo.commitConditional(
        request([
          put(Sample('A', id: id('a')), unique: 'a'),
          put(Sample('B', id: id('b')), unique: 'b'),
        ]),
      );
      check(
        created.decision == CommitDecision.committed,
        'Two-record create committed',
      );
      remember(created);
      final firstRevision = created.revisions[id('a')]!;
      final updated = await repo.commitConditional(
        request([
          put(
            Sample('A2', id: id('a')),
            revision: firstRevision,
            unique: 'a',
          ),
          put(
            Sample('B2', id: id('b')),
            revision: created.revisions[id('b')]!,
            unique: 'b',
          ),
        ]),
      );
      check(
        updated.decision == CommitDecision.committed,
        'Two-record update committed',
      );
      remember(updated);
      state['aRevision'] = updated.revisions[id('a')];
      state['bRevision'] = updated.revisions[id('b')];
      save();
      final stale = await repo.commitConditional(
        request([
          put(
            Sample('must not appear', id: id('b')),
            revision: updated.revisions[id('b')],
            unique: 'b',
          ),
          put(
            Sample('stale', id: id('a')),
            revision: firstRevision,
            unique: 'a',
          ),
        ]),
      );
      check(
        stale.decision == CommitDecision.rejected &&
            stale.rejection == CommitRejection.staleRevision,
        'Stale revision rejects entire multi-record operation',
      );
      remember(stale);
      check(
        (await repo.getVersioned(id('b'))).aggregate.label == 'B2',
        'Rejected operation did not partially update the other record',
      );
      final collision = await repo.commitConditional(
        request([put(Sample('collision', id: id('collision')), unique: 'a')]),
      );
      check(
        collision.decision == CommitDecision.rejected &&
            collision.rejection == CommitRejection.uniqueConflict,
        'Duplicate unique value rejected',
      );
      remember(collision);
      await error(
        () => repo.getById(id('collision')),
        RepositoryExceptionType.notFound,
        'Rejected unique claimant absent',
      );

      final aba = await repo.commitConditional(
        request([put(Sample('original', id: id('aba')))]),
      );
      check(aba.decision == CommitDecision.committed, 'ABA seed committed');
      remember(aba);
      final removed = await repo.commitConditional(
        request([
          ConditionalMutation.delete(
            id('aba'),
            expected: ExpectedRevision.match(aba.revisions[id('aba')]!),
          ),
        ]),
      );
      check(
        removed.decision == CommitDecision.committed,
        'Conditional deletion committed',
      );
      remember(removed);
      final recreated = await repo.commitConditional(
        request([put(Sample('recreated', id: id('aba')))]),
      );
      check(
        recreated.decision == CommitDecision.committed &&
            recreated.revisions[id('aba')] != aba.revisions[id('aba')],
        'Delete/recreate generates a new revision',
      );
      remember(recreated);
      final oldToken = await repo.commitConditional(
        request([
          put(
            Sample('wrong', id: id('aba')),
            revision: aba.revisions[id('aba')],
          ),
        ]),
      );
      check(
        oldToken.rejection == CommitRejection.staleRevision,
        'ABA stale token rejected',
      );
      remember(oldToken);
      state['abaRevision'] = recreated.revisions[id('aba')];
      state['baselineComplete'] = true;
      save();
    } finally {
      await repo.close();
    }
    await verify();
  }

  Future<void> verify() async {
    if (state['baselineComplete'] != true)
      throw StateError('Baseline has not completed.');
    final repo = repository('main');
    try {
      check(
        (await repo.getById(id('crud'))).label == 'updated',
        'Committed CRUD value retained',
      );
      for (final key in ['deleted', 'collision']) {
        await error(
          () => repo.getById(id(key)),
          RepositoryExceptionType.notFound,
          '$key remains absent',
        );
      }
      for (final entry in {'a': 'A2', 'b': 'B2', 'aba': 'recreated'}.entries) {
        final value = await repo.getVersioned(id(entry.key));
        check(
          value.aggregate.label == entry.value &&
              value.revision == state['${entry.key}Revision'],
          '${entry.key}: committed value and exact revision retained',
        );
      }
      for (final key in ['a', 'b']) {
        check(
          (await repo.findUnique(UniqueValue('label', key))).aggregate.id ==
              id(key),
          '$key: unique ownership retained',
        );
      }
    } finally {
      await repo.close();
    }
    for (final raw in receipts) {
      final saved = raw as Map<String, dynamic>;
      final receiptRepo = repository(saved['database'] as String);
      try {
        final found = await receiptRepo.resolveOperation(
          UuidValue.fromString(saved['operationId'] as String),
          saved['digest'] as String,
        );
        final revisions = saved['revisions'] as Map<String, dynamic>;
        check(
          found.decision.name == saved['decision'] &&
              found.rejection?.name == saved['rejection'] &&
              found.revisions.length == revisions.length &&
              found.revisions.entries.every(
                (e) => revisions[e.key.uuid] == e.value,
              ),
          'Durable ${saved['decision']} receipt ${saved['operationId']}',
        );
      } finally {
        await receiptRepo.close();
      }
    }
    if (state['recoveryComplete'] == true) await verifyRecovery();
  }

  ConditionalCommit<Sample, UuidValue> pendingRequest() => request([
    put(Sample('recovered A', id: id('pendingA')), unique: 'recovery-a'),
    put(Sample('recovered B', id: id('pendingB')), unique: 'recovery-b'),
  ], operation: id('pendingOperation'));

  /// Persist caller intent before dispatch. Deliberately discard the result;
  /// the UI reloads and reconstructs the exact request from this manifest.
  Future<void> dispatchUnobserved() async {
    if (state['pendingOperation'] != null)
      throw StateError('A recovery operation already exists for this run.');
    for (final key in ['pendingA', 'pendingB', 'pendingOperation']) {
      state[key] = UuidValue.generate().uuid;
    }
    final repo = repository('recovery');
    state['pendingDigest'] = repo.digestFor(pendingRequest());
    state['recoveryDispatchedAt'] = DateTime.now().toUtc().toIso8601String();
    save();
    try {
      // Await transport settlement only. Never inspect or store its decision,
      // receipt or revisions: recovery must learn them from IndexedDB.
      await repo.commitConditional(pendingRequest());
    } catch (_) {
      // A lost response includes a response that never reached the caller.
    } finally {
      await repo.close();
    }
    log(
      'info',
      'Completion deliberately discarded; this is not a forced OS crash.',
    );
  }

  Future<void> reconcile() async {
    if (state['pendingOperation'] == null)
      throw StateError('Dispatch the unobserved operation first.');
    final repo = repository('recovery');
    try {
      final pending = pendingRequest();
      final digest = state['pendingDigest'] as String;
      check(
        repo.digestFor(pending) == digest,
        'Reload reconstructed identical request digest',
      );
      final resolved = await repo.resolveOperation(pending.operationId, digest);
      log(
        'info',
        'Initial reconciliation: ${resolved.decision.name}; absent receipts mean uncertain.',
      );
      final retried = await repo.commitConditional(pending);
      check(
        retried.decision == CommitDecision.committed,
        'Exact operation retry committed or recovered receipt',
      );
      if (resolved.decision == CommitDecision.committed) {
        check(
          resolved.revisions.length == retried.revisions.length &&
              resolved.revisions.entries.every(
                (e) => retried.revisions[e.key] == e.value,
              ),
          'Retry preserved reconciled revisions',
        );
      } else {
        check(
          resolved.decision == CommitDecision.uncertain,
          'Unobserved outcome was uncertain, not rejected',
        );
      }
      final again = await repo.commitConditional(pending);
      check(
        again.revisions.length == retried.revisions.length &&
            again.revisions.entries.every(
              (e) => retried.revisions[e.key] == e.value,
            ),
        'Second identical retry did not apply mutations again',
      );
      final changed = request([
        put(Sample('different payload', id: id('pendingA'))),
      ], operation: pending.operationId);
      await error(
        () => repo.commitConditional(changed),
        RepositoryExceptionType.constraint,
        'Same operation ID with changed payload rejected',
      );
      state['pendingARevision'] = retried.revisions[id('pendingA')];
      state['pendingBRevision'] = retried.revisions[id('pendingB')];
      remember(retried, suffix: 'recovery');
      state['recoveryComplete'] = true;
      save();
    } finally {
      await repo.close();
    }
    await verifyRecovery();
  }

  Future<void> verifyRecovery() async {
    final repo = repository('recovery');
    try {
      for (final entry in {
        'pendingA': 'recovered A',
        'pendingB': 'recovered B',
      }.entries) {
        final found = await repo.getVersioned(id(entry.key));
        check(
          found.aggregate.label == entry.value &&
              found.revision == state['${entry.key}Revision'],
          '${entry.key}: recovered value and revision retained',
        );
      }
    } finally {
      await repo.close();
    }
  }

  Future<Object?> rawRead(String suffix, String key, {int version = 2}) async {
    final db = await factory.open('$prefix-$suffix', version: version);
    try {
      final tx = db.transaction('samples', idbModeReadOnly);
      final done = tx.completed;
      final value = await tx.objectStore('samples').getObject(key);
      await done;
      return value;
    } finally {
      db.close();
    }
  }

  Future<void> failures() async {
    if (state['failuresStarted'] == true)
      throw StateError('Failure suite already started; preserve this report.');
    state['failuresStarted'] = true;
    save();
    final sample = Sample('legacy safe');
    final old = await factory.open(
      '$prefix-schema',
      version: 1,
      onUpgradeNeeded: (event) => event.database.createObjectStore('samples'),
    );
    final tx = old.transaction('samples', idbModeReadWrite);
    final done = tx.completed;
    final envelope = {
      'id': sample.id.uuid,
      'codecVersion': 1,
      'payload': encode(sample),
    };
    await tx.objectStore('samples').put(envelope, sample.id.uuid);
    await done;
    old.close();

    final interrupted = repository(
      'schema',
      using: FaultFactory(factory, abortUpgrade: true),
    );
    try {
      await error(
        () => interrupted.getById(sample.id),
        RepositoryExceptionType.connection,
        'INJECTED upgrade abort reports connection failure',
      );
    } finally {
      await interrupted.close();
    }
    check(
      (await rawRead('schema', sample.id.uuid, version: 1) as Map)['payload'] ==
          encode(sample),
      'Native rollback preserved version-1 data after INJECTED abort',
    );
    check(
      await rawRead('schema', '__dddart_schema__', version: 1) == null,
      'Aborted upgrade did not commit schema marker',
    );
    final compatible = repository('schema');
    try {
      check(
        (await compatible.getById(sample.id)).label == sample.label,
        'Compatible upgrade retry retained data',
      );
    } finally {
      await compatible.close();
    }
    final incompatible = repository('schema', codec: 2);
    try {
      await error(
        () => incompatible.getById(sample.id),
        RepositoryExceptionType.constraint,
        'Native codec mismatch rejected',
      );
    } finally {
      await incompatible.close();
    }
    check(
      (await rawRead('schema', sample.id.uuid) as Map)['payload'] ==
          encode(sample),
      'Codec mismatch preserved original payload',
    );

    final unavailable = repository(
      'schema',
      using: FaultFactory(factory, unavailable: true),
    );
    try {
      await error(
        () => unavailable.getById(sample.id),
        RepositoryExceptionType.connection,
        'INJECTED unavailable storage reports typed connection failure',
      );
    } finally {
      await unavailable.close();
    }
    final available = repository('schema');
    try {
      check(
        (await available.getById(sample.id)).label == sample.label,
        'Native storage works again after removing injected unavailability',
      );
    } finally {
      await available.close();
    }

    final faultFactory = FaultFactory(factory, failReceipt: true);
    final faultRepo = repository('fault', using: faultFactory);
    final a = Sample('fault A');
    final b = Sample('fault B');
    final pending = request([
      put(a, unique: 'fault-a'),
      put(b, unique: 'fault-b'),
    ]);
    try {
      final failed = await faultRepo.commitConditional(pending);
      check(
        failed.decision == CommitDecision.uncertain,
        'INJECTED receipt write failure yields uncertain outcome',
      );
      for (final sample in [a, b]) {
        await error(
          () => faultRepo.getById(sample.id),
          RepositoryExceptionType.notFound,
          'Native transaction rolled back queued aggregate after injected failure',
        );
      }
      for (final key in ['fault-a', 'fault-b']) {
        await error(
          () => faultRepo.findUnique(UniqueValue('label', key)),
          RepositoryExceptionType.notFound,
          'Unique claim rolled back: $key',
        );
      }
      check(
        await rawRead(
                  'fault',
                  '__dddart_receipt__${pending.operationId.uuid}',
                ) ==
                null &&
            await rawRead('fault', '__dddart_receipt_count__') == null,
        'No partial receipt or receipt count survived abort',
      );
      check(
        (await faultRepo.resolveOperation(
              pending.operationId,
              failed.payloadDigest,
            )).decision ==
            CommitDecision.uncertain,
        'Missing receipt correctly remains uncertain',
      );
      final recovered = await faultRepo.commitConditional(pending);
      check(
        recovered.decision == CommitDecision.committed,
        'Exact retry succeeds after removing injected fault',
      );
      check(
        (await faultRepo.getById(a.id)).label == a.label &&
            (await faultRepo.getById(b.id)).label == b.label,
        'Both recovered records present',
      );
      remember(recovered, suffix: 'fault');
    } finally {
      await faultRepo.close();
    }
    state['failuresComplete'] = true;
    save();
  }
}

/// These wrappers inject faults into real native IndexedDB; never memory storage.
class FaultFactory implements IdbFactory {
  FaultFactory(
    this.delegate, {
    this.abortUpgrade = false,
    this.unavailable = false,
    this.failReceipt = false,
  });
  final IdbFactory delegate;
  final bool abortUpgrade;
  final bool unavailable;
  bool failReceipt;
  @override
  Future<Database> open(
    String name, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    if (unavailable) throw StateError('INJECTED storage unavailable');
    final db = await delegate.open(
      name,
      version: version,
      onBlocked: onBlocked,
      onUpgradeNeeded: (event) async {
        await onUpgradeNeeded?.call(event);
        if (abortUpgrade) event.transaction.abort();
      },
    );
    return FaultDatabase(this, db);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FaultDatabase extends Database {
  FaultDatabase(FaultFactory super.factory, this.delegate);
  final Database delegate;
  @override
  Stream<VersionChangeEvent> get onVersionChange => delegate.onVersionChange;
  @override
  Iterable<String> get objectStoreNames => delegate.objectStoreNames;
  @override
  Transaction transaction(Object stores, String mode) => FaultTransaction(
    delegate.transaction(stores, mode),
    factory as FaultFactory,
  );
  @override
  void close() => delegate.close();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FaultTransaction implements Transaction {
  FaultTransaction(this.delegate, this.factory);
  final Transaction delegate;
  final FaultFactory factory;
  @override
  Future<Database> get completed => delegate.completed;
  @override
  ObjectStore objectStore(String name) =>
      FaultStore(delegate.objectStore(name), factory);
  @override
  void abort() => delegate.abort();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FaultStore implements ObjectStore {
  FaultStore(this.delegate, this.factory);
  final ObjectStore delegate;
  final FaultFactory factory;
  @override
  Future<Object?> getObject(Object key) => delegate.getObject(key);
  @override
  Future<Object> put(Object value, [Object? key]) {
    if (factory.failReceipt &&
        key is String &&
        key.startsWith('__dddart_receipt__')) {
      factory.failReceipt = false;
      return Future.error(StateError('INJECTED receipt write failure'));
    }
    return delegate.put(value, key);
  }

  @override
  Future<void> delete(Object keyOrRange) => delegate.delete(keyOrRange);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
