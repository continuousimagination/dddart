import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

class _Sample extends AggregateRoot {
  _Sample({required this.name, super.id});

  final String name;
}

IndexedDbRepository<_Sample> _repository(
  String databaseName, {
  IdbFactory? factory,
  int maxReceipts = 100000,
}) =>
    IndexedDbRepository<_Sample>(
      factory: factory ?? newIdbFactoryMemory(),
      databaseName: databaseName,
      storeName: 'samples',
      maxReceipts: maxReceipts,
      encode: (value) => jsonEncode({'id': value.id.uuid, 'name': value.name}),
      decode: (value) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        return _Sample(
          id: UuidValue.fromString(data['id'] as String),
          name: data['name'] as String,
        );
      },
    );

/// Lets the real in-memory transaction commit, then loses its acknowledgment.
class _LostAckFactory implements IdbFactory {
  _LostAckFactory(this.delegate);

  final IdbFactory delegate;
  bool loseNextWriteAck = false;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async =>
      _LostAckDatabase(
        this,
        await delegate.open(
          dbName,
          version: version,
          onUpgradeNeeded: onUpgradeNeeded,
          onBlocked: onBlocked,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _LostAckDatabase extends Database {
  _LostAckDatabase(super.factory, this.delegate);

  final Database delegate;

  @override
  Iterable<String> get objectStoreNames => delegate.objectStoreNames;

  @override
  Transaction transaction(Object storeNameOrStoreNames, String mode) {
    final factory = super.factory as _LostAckFactory;
    final loseAck = mode == idbModeReadWrite && factory.loseNextWriteAck;
    if (loseAck) factory.loseNextWriteAck = false;
    return _LostAckTransaction(
      delegate.transaction(storeNameOrStoreNames, mode),
      loseAck,
    );
  }

  @override
  void close() => delegate.close();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _LostAckTransaction implements Transaction {
  _LostAckTransaction(this.delegate, this.loseAck);

  final Transaction delegate;
  final bool loseAck;

  @override
  Future<Database> get completed => loseAck
      ? delegate.completed.then((_) => throw StateError('acknowledgment lost'))
      : delegate.completed;

  @override
  ObjectStore objectStore(String name) => delegate.objectStore(name);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ConditionalCommit<_Sample> _put(
  _Sample sample,
  ExpectedRevision expected, {
  UuidValue? operationId,
  String? uniqueName,
}) =>
    ConditionalCommit(
      operationId: operationId ?? UuidValue.generate(),
      mutations: [
        ConditionalMutation<_Sample>.put(
          sample,
          expected: expected,
          uniqueValues: [
            if (uniqueName != null) UniqueValue('name', uniqueName)
          ],
        ),
      ],
    );

void main() {
  test('receipt cap rejects new operations without losing old receipts',
      () async {
    final repository = _repository('capacity', maxReceipts: 1);
    final first = _Sample(name: 'First');
    final request = _put(first, const ExpectedRevision.absent());
    expect((await repository.commitConditional(request)).decision,
        CommitDecision.committed);
    await expectLater(
      repository.commitConditional(_put(
        _Sample(name: 'Second'),
        const ExpectedRevision.absent(),
      )),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    expect(
        (await repository.resolveOperation(
          request.operationId,
          repository.digestFor(request),
        ))
            .decision,
        CommitDecision.committed);
    expect((await repository.commitConditional(request)).decision,
        CommitDecision.committed);
    await repository.close();
  });

  test('lost commit acknowledgment reconciles without applying twice',
      () async {
    final factory = _LostAckFactory(newIdbFactoryMemory());
    final repository = _repository('unknown', factory: factory);
    final sample = _Sample(name: 'Persisted');
    final request = _put(
      sample,
      const ExpectedRevision.absent(),
      uniqueName: 'persisted',
    );
    factory.loseNextWriteAck = true;
    final uncertain = await repository.commitConditional(request);
    expect(uncertain.decision, CommitDecision.uncertain);
    final resolved = await repository.resolveOperation(
      uncertain.operationId,
      uncertain.payloadDigest,
    );
    expect(resolved.decision, CommitDecision.committed);
    final revision = resolved.revisions[sample.id];
    expect((await repository.getVersioned(sample.id)).revision, revision);
    final retried = await repository.commitConditional(request);
    expect(retried.decision, CommitDecision.committed);
    expect(retried.revisions[sample.id], revision);
    expect(
        (await repository.findUnique(const UniqueValue('name', 'persisted')))
            .aggregate
            .id,
        sample.id);
    await repository.close();
  });

  test('receipt makes retry idempotent and rejects changed payload', () async {
    final repository = _repository('retry');
    final sample = _Sample(name: 'First');
    final request = _put(
      sample,
      const ExpectedRevision.absent(),
      uniqueName: 'first',
    );
    final digest = repository.digestFor(request);
    final first = await repository.commitConditional(request);
    expect(first.decision, CommitDecision.committed);
    expect(first.payloadDigest, digest);
    final revision = first.revisions[sample.id];
    expect(revision, isNotNull);
    expect((await repository.getVersioned(sample.id)).revision, revision);
    expect(
        (await repository.findUnique(const UniqueValue('name', 'first')))
            .aggregate
            .name,
        'First');

    final retried = await repository.commitConditional(request);
    expect(retried.decision, CommitDecision.committed);
    expect(retried.revisions[sample.id], revision);
    final resolved =
        await repository.resolveOperation(request.operationId, digest);
    expect(resolved.decision, CommitDecision.committed);
    expect(resolved.revisions[sample.id], revision);
    await expectLater(
      repository.commitConditional(_put(
        _Sample(id: sample.id, name: 'Changed'),
        const ExpectedRevision.absent(),
        operationId: request.operationId,
      )),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    expect((await repository.getVersioned(sample.id)).aggregate.name, 'First');
    await repository.close();
  });

  test('stale batch preserves both records and unique claims', () async {
    final repository = _repository('batch');
    final a = _Sample(name: 'Alpha');
    final b = _Sample(name: 'Beta');
    final create = ConditionalCommit<_Sample>(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(
          a,
          expected: const ExpectedRevision.absent(),
          uniqueValues: const [UniqueValue('name', 'alpha')],
        ),
        ConditionalMutation.put(
          b,
          expected: const ExpectedRevision.absent(),
          uniqueValues: const [UniqueValue('name', 'beta')],
        ),
      ],
    );
    expect((await repository.commitConditional(create)).decision,
        CommitDecision.committed);
    final aVersion = (await repository.getVersioned(a.id)).revision;
    final bVersion = (await repository.getVersioned(b.id)).revision;

    final swap = ConditionalCommit<_Sample>(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(
          _Sample(id: a.id, name: 'Beta'),
          expected: ExpectedRevision.match(aVersion),
          uniqueValues: const [UniqueValue('name', 'beta')],
        ),
        ConditionalMutation.put(
          _Sample(id: b.id, name: 'Alpha'),
          expected: ExpectedRevision.match(bVersion),
          uniqueValues: const [UniqueValue('name', 'alpha')],
        ),
      ],
    );
    expect((await repository.commitConditional(swap)).decision,
        CommitDecision.committed);
    expect(
        (await repository.findUnique(const UniqueValue('name', 'beta')))
            .aggregate
            .id,
        a.id);
    expect(
        (await repository.findUnique(const UniqueValue('name', 'alpha')))
            .aggregate
            .id,
        b.id);

    final stale = await repository.commitConditional(ConditionalCommit(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation<_Sample>.put(
          _Sample(id: a.id, name: 'Stale'),
          expected: ExpectedRevision.match(aVersion),
          uniqueValues: const [UniqueValue('name', 'stale')],
        ),
        ConditionalMutation<_Sample>.delete(
          b.id,
          expected: ExpectedRevision.match(bVersion),
        ),
      ],
    ));
    expect(stale.decision, CommitDecision.rejected);
    expect(stale.rejection, CommitRejection.staleRevision);
    expect((await repository.getVersioned(a.id)).aggregate.name, 'Beta');
    expect((await repository.getVersioned(b.id)).aggregate.name, 'Alpha');
    await repository.close();
  });

  test('unique collision and delete-recreate cannot defeat old revision',
      () async {
    final repository = _repository('aba');
    final a = _Sample(name: 'A');
    final b = _Sample(name: 'B');
    final created = await repository.commitConditional(_put(
      a,
      const ExpectedRevision.absent(),
      uniqueName: 'a',
    ));
    final oldRevision = created.revisions[a.id]!;
    final collisionRequest = _put(
      b,
      const ExpectedRevision.absent(),
      uniqueName: 'a',
    );
    final collision = await repository.commitConditional(collisionRequest);
    expect(collision.decision, CommitDecision.rejected);
    expect(collision.rejection, CommitRejection.uniqueConflict);
    await expectLater(
      repository.getVersioned(b.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.notFound,
      )),
    );
    final deleted = await repository.commitConditional(ConditionalCommit(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation<_Sample>.delete(
          a.id,
          expected: ExpectedRevision.match(oldRevision),
        ),
      ],
    ));
    expect(deleted.decision, CommitDecision.committed);
    final oldRejection = await repository.commitConditional(collisionRequest);
    expect(oldRejection.decision, CommitDecision.rejected);
    expect(oldRejection.rejection, CommitRejection.uniqueConflict);
    final recreated = await repository.commitConditional(_put(
      _Sample(id: a.id, name: 'New A'),
      const ExpectedRevision.absent(),
      uniqueName: 'a',
    ));
    expect(recreated.decision, CommitDecision.committed);
    expect(recreated.revisions[a.id], isNot(oldRevision));
    final stale = await repository.commitConditional(_put(
      _Sample(id: a.id, name: 'Old writer'),
      ExpectedRevision.match(oldRevision),
      uniqueName: 'a',
    ));
    expect(stale.rejection, CommitRejection.staleRevision);
    expect((await repository.getVersioned(a.id)).aggregate.name, 'New A');
    await repository.close();
  });

  test('basic CRUD cannot overwrite a conditionally managed aggregate',
      () async {
    final repository = _repository('guard');
    final sample = _Sample(name: 'Safe');
    await repository.commitConditional(
      _put(sample, const ExpectedRevision.absent()),
    );
    await expectLater(
      repository.save(_Sample(id: sample.id, name: 'Bypass')),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    await expectLater(
      repository.deleteById(sample.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    expect((await repository.getVersioned(sample.id)).aggregate.name, 'Safe');
    await repository.close();
  });
}
