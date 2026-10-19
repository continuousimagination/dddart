@TestOn('browser')
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

class _Sample extends AggregateRoot {
  _Sample({required this.name, super.id});

  final String name;
}

/// Fails receipt request setup while leaving earlier native writes queued.
class _ReceiptFaultFactory implements IdbFactory {
  _ReceiptFaultFactory(this.delegate);

  final IdbFactory delegate;
  bool failReceiptPut = false;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async =>
      _ReceiptFaultDatabase(
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

class _ReceiptFaultDatabase extends Database {
  _ReceiptFaultDatabase(super.factory, this.delegate);

  final Database delegate;

  @override
  Iterable<String> get objectStoreNames => delegate.objectStoreNames;

  @override
  Transaction transaction(Object storeNameOrStoreNames, String mode) =>
      _ReceiptFaultTransaction(
        delegate.transaction(storeNameOrStoreNames, mode),
        super.factory as _ReceiptFaultFactory,
      );

  @override
  void close() => delegate.close();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _ReceiptFaultTransaction implements Transaction {
  _ReceiptFaultTransaction(this.delegate, this.factory);

  final Transaction delegate;
  final _ReceiptFaultFactory factory;

  @override
  Future<Database> get completed => delegate.completed;

  @override
  ObjectStore objectStore(String name) =>
      _ReceiptFaultStore(delegate.objectStore(name), factory);

  @override
  void abort() => delegate.abort();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _ReceiptFaultStore implements ObjectStore {
  _ReceiptFaultStore(this.delegate, this.factory);

  final ObjectStore delegate;
  final _ReceiptFaultFactory factory;

  @override
  Future<Object?> getObject(Object key) => delegate.getObject(key);

  @override
  Future<Object> put(Object value, [Object? key]) {
    if (factory.failReceiptPut &&
        key is String &&
        key.startsWith('__dddart_receipt__')) {
      factory.failReceiptPut = false;
      return Future.error(StateError('receipt request setup failed'));
    }
    return delegate.put(value, key);
  }

  @override
  Future<void> delete(Object keyOrRange) => delegate.delete(keyOrRange);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test('failed receipt setup aborts queued native records and index writes',
      () async {
    final nativeFactory = idbFactoryNative;
    final name = 'dddart-receipt-fault-${UuidValue.generate()}';
    final faultFactory = _ReceiptFaultFactory(nativeFactory)
      ..failReceiptPut = true;
    final repository = IndexedDbRepository<_Sample>(
      factory: faultFactory,
      databaseName: name,
      storeName: 'samples',
      encode: (value) => jsonEncode({
        'id': value.id.uuid,
        'name': value.name,
      }),
      decode: (value) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        return _Sample(
          id: UuidValue.fromString(data['id'] as String),
          name: data['name'] as String,
        );
      },
    );
    final a = _Sample(name: 'A');
    final b = _Sample(name: 'B');
    final request = ConditionalCommit<_Sample>(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(
          a,
          expected: const ExpectedRevision.absent(),
          uniqueValues: const [UniqueValue('name', 'a')],
        ),
        ConditionalMutation.put(
          b,
          expected: const ExpectedRevision.absent(),
          uniqueValues: const [UniqueValue('name', 'b')],
        ),
      ],
    );
    try {
      final result = await repository.commitConditional(request);
      expect(result.decision, CommitDecision.uncertain);
      for (final id in [a.id, b.id]) {
        await expectLater(
          repository.getVersioned(id),
          throwsA(isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.notFound,
          )),
        );
      }
      await expectLater(
        repository.findUnique(const UniqueValue('name', 'a')),
        throwsA(isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.notFound,
        )),
      );
      expect(
          (await repository.resolveOperation(
            request.operationId,
            result.payloadDigest,
          ))
              .decision,
          CommitDecision.uncertain);
      final rawDb = await nativeFactory.open(name, version: 1);
      try {
        final transaction = rawDb.transaction('samples', idbModeReadOnly);
        final completed = transaction.completed;
        final store = transaction.objectStore('samples');
        expect(
            await store
                .getObject('__dddart_receipt__${request.operationId.uuid}'),
            isNull);
        expect(await store.getObject('__dddart_receipt_count__'), isNull);
        await completed;
      } finally {
        rawDb.close();
      }
      expect((await repository.commitConditional(request)).decision,
          CommitDecision.committed);
      expect((await repository.getVersioned(a.id)).aggregate.name, 'A');
      expect((await repository.getVersioned(b.id)).aggregate.name, 'B');
    } finally {
      await repository.close();
      await nativeFactory.deleteDatabase(name);
    }
  });

  test('native IndexedDB serializes racing writers and unique claims',
      () async {
    final factory = idbFactoryNative;
    final name = 'dddart-conditional-${UuidValue.generate()}';
    IndexedDbRepository<_Sample> repository() => IndexedDbRepository<_Sample>(
          factory: factory,
          databaseName: name,
          storeName: 'samples',
          encode: (value) => jsonEncode({
            'id': value.id.uuid,
            'name': value.name,
          }),
          decode: (value) {
            final data = jsonDecode(value) as Map<String, dynamic>;
            return _Sample(
              id: UuidValue.fromString(data['id'] as String),
              name: data['name'] as String,
            );
          },
        );
    final first = repository();
    final second = repository();
    final a = _Sample(name: 'Original');
    try {
      final created = await first.commitConditional(ConditionalCommit(
        operationId: UuidValue.generate(),
        mutations: [
          ConditionalMutation<_Sample>.put(
            a,
            expected: const ExpectedRevision.absent(),
            uniqueValues: const [UniqueValue('name', 'original')],
          ),
        ],
      ));
      expect(created.decision, CommitDecision.committed);
      final oldRevision = (await first.getVersioned(a.id)).revision;
      expect((await second.getVersioned(a.id)).revision, oldRevision);

      ConditionalCommit<_Sample> update(String label) => ConditionalCommit(
            operationId: UuidValue.generate(),
            mutations: [
              ConditionalMutation<_Sample>.put(
                _Sample(id: a.id, name: label),
                expected: ExpectedRevision.match(oldRevision),
                uniqueValues: [UniqueValue('name', label.toLowerCase())],
              ),
            ],
          );
      final left = update('Left');
      final right = update('Right');
      final results = await Future.wait([
        first.commitConditional(left),
        second.commitConditional(right),
      ]);
      expect(results.map((result) => result.decision),
          containsAll([CommitDecision.committed, CommitDecision.rejected]));
      final winner = results.singleWhere(
        (result) => result.decision == CommitDecision.committed,
      );
      final loser = results.singleWhere(
        (result) => result.decision == CommitDecision.rejected,
      );
      expect(loser.rejection, CommitRejection.staleRevision);
      expect((await first.getVersioned(a.id)).revision, winner.revisions[a.id]);
      expect(
          (await second.resolveOperation(
            loser.operationId,
            loser.payloadDigest,
          ))
              .rejection,
          CommitRejection.staleRevision);

      final b = _Sample(name: 'B');
      final c = _Sample(name: 'C');
      ConditionalCommit<_Sample> claim(_Sample sample) => ConditionalCommit(
            operationId: UuidValue.generate(),
            mutations: [
              ConditionalMutation<_Sample>.put(
                sample,
                expected: const ExpectedRevision.absent(),
                uniqueValues: const [UniqueValue('name', 'shared')],
              ),
            ],
          );
      final claims = await Future.wait([
        first.commitConditional(claim(b)),
        second.commitConditional(claim(c)),
      ]);
      expect(claims.map((result) => result.decision),
          containsAll([CommitDecision.committed, CommitDecision.rejected]));
      expect(
          claims
              .singleWhere(
                (result) => result.decision == CommitDecision.rejected,
              )
              .rejection,
          CommitRejection.uniqueConflict);
      final owner = await first.findUnique(const UniqueValue('name', 'shared'));
      expect(owner.aggregate.id, anyOf(b.id, c.id));

      final currentA = await first.getVersioned(a.id);
      final oldAName = currentA.aggregate.name.toLowerCase();
      final swapped = await second.commitConditional(ConditionalCommit(
        operationId: UuidValue.generate(),
        mutations: [
          ConditionalMutation<_Sample>.put(
            _Sample(id: a.id, name: 'Shared'),
            expected: ExpectedRevision.match(currentA.revision),
            uniqueValues: const [UniqueValue('name', 'shared')],
          ),
          ConditionalMutation<_Sample>.put(
            _Sample(id: owner.aggregate.id, name: 'Former A'),
            expected: ExpectedRevision.match(owner.revision),
            uniqueValues: [UniqueValue('name', oldAName)],
          ),
        ],
      ));
      expect(swapped.decision, CommitDecision.committed);
      expect(
          (await first.findUnique(const UniqueValue('name', 'shared')))
              .aggregate
              .id,
          a.id);
      expect(
          (await first.findUnique(UniqueValue('name', oldAName))).aggregate.id,
          owner.aggregate.id);
    } finally {
      await first.close();
      await second.close();
      await factory.deleteDatabase(name);
    }
  });
}
