import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:idb_shim/idb.dart';
import 'package:test/test.dart';

class ScopedId extends Identity {
  const ScopedId(this.scope, this.number);
  final String scope;
  final int number;
  @override
  List<Object?> get props => [scope, number];
}

class ScopedCodec implements IdentityCodec<ScopedId> {
  const ScopedCodec();
  @override
  Object toJson(ScopedId identity) => [identity.scope, identity.number];
  @override
  ScopedId fromJson(Object? value) {
    final parts = value! as List;
    return ScopedId(parts[0] as String, parts[1] as int);
  }

  @override
  String toKey(ScopedId identity) => jsonEncode(toJson(identity));
  @override
  ScopedId fromKey(String value) => fromJson(jsonDecode(value));
}

class ScopedAggregate extends AggregateRoot<ScopedId> {
  ScopedAggregate({required super.id, required this.label});
  final String label;
}

String encodeScoped(ScopedAggregate aggregate) => jsonEncode({
      'id': const ScopedCodec().toJson(aggregate.id),
      'label': aggregate.label,
    });

ScopedAggregate decodeScoped(String snapshot) {
  final data = jsonDecode(snapshot) as Map<String, dynamic>;
  return ScopedAggregate(
    id: const ScopedCodec().fromJson(data['id']),
    label: data['label'] as String,
  );
}

IdentityCodecRegistry scopedCodecs() =>
    IdentityCodecRegistry()..register<ScopedId>('scoped', const ScopedCodec());

class _TextId extends Identity {
  const _TextId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class _TextCodec implements IdentityCodec<_TextId> {
  const _TextCodec();
  @override
  Object toJson(_TextId identity) => identity.value;
  @override
  _TextId fromJson(Object? value) => _TextId(value! as String);
  @override
  String toKey(_TextId identity) => identity.value;
  @override
  _TextId fromKey(String value) => _TextId(value);
}

class _TextAggregate extends AggregateRoot<_TextId> {
  _TextAggregate({required super.id});
}

class _TrackingFactory implements IdbFactory {
  _TrackingFactory(this.delegate);
  final IdbFactory delegate;
  int opens = 0;

  @override
  Future<Database> open(
    String name, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) {
    opens++;
    return delegate.open(name,
        version: version,
        onUpgradeNeeded: onUpgradeNeeded,
        onBlocked: onBlocked);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// Run identical typed contracts against memory and native IndexedDB factories.
void typedIdentityContract(IdbFactory Function() createFactory) {
  test(
      'raw keys cannot alias UUID/metadata; malformed Unicode fails before I/O',
      () async {
    final factory = createFactory();
    final name = 'typed-key-${UuidValue.generate()}';
    final tracking = _TrackingFactory(factory);
    final codecs = IdentityCodecRegistry()
      ..register<_TextId>('text', const _TextCodec());
    final repo = IndexedDbRepository<_TextAggregate, _TextId>(
      factory: tracking,
      databaseName: name,
      storeName: 'aggregates',
      identityCodecs: codecs,
      encode: (value) => jsonEncode(value.id.value),
      decode: (value) =>
          _TextAggregate(id: _TextId(jsonDecode(value) as String)),
    );
    final ids = [
      const _TextId(''),
      const _TextId('__dddart_schema__'),
      const _TextId('__dddart_receipt_count__'),
      const _TextId('__dddart_unique__value'),
      _TextId(UuidValue.generate().uuid),
      const _TextId('雪 /?#%'),
    ];
    try {
      final invalid = _TextId(String.fromCharCode(0xd800));
      final constraint = isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.constraint);
      await expectLater(
          repo.save(_TextAggregate(id: invalid)), throwsA(constraint));
      await expectLater(repo.getById(invalid), throwsA(constraint));
      await expectLater(repo.deleteById(invalid), throwsA(constraint));
      await expectLater(repo.getVersioned(invalid), throwsA(constraint));
      expect(
          () => repo.digestFor(ConditionalCommit<_TextAggregate, _TextId>(
                operationId: UuidValue.generate(),
                mutations: [
                  ConditionalMutation.put(_TextAggregate(id: invalid),
                      expected: const ExpectedRevision.absent())
                ],
              )),
          throwsA(constraint));
      // Failed key validation has not even created the database.
      expect(tracking.opens, 0);
      for (final id in ids) {
        await repo.save(_TextAggregate(id: id));
      }
      for (final id in ids) {
        expect((await repo.getById(id)).id, id);
      }
      expect(
          () => IndexedDbRepository<_TextAggregate, _TextId>(
                factory: factory,
                databaseName: name,
                storeName: 'aggregates',
                encode: (value) => '',
                decode: (_) => _TextAggregate(id: ids.first),
              ),
          throwsArgumentError);
    } finally {
      await repo.close();
      await factory.deleteDatabase(name);
    }
  });

  test(
      'scoped CRUD survives reopen and keeps scope, case and metadata separate',
      () async {
    final factory = createFactory();
    final name = 'typed-crud-${UuidValue.generate()}';
    IndexedDbRepository<ScopedAggregate, ScopedId> repository() =>
        IndexedDbRepository<ScopedAggregate, ScopedId>(
          factory: factory,
          databaseName: name,
          storeName: 'aggregates',
          identityCodecs: scopedCodecs(),
          encode: encodeScoped,
          decode: decodeScoped,
        );
    final first = repository();
    final ids = [
      const ScopedId('__dddart_schema__', 12),
      const ScopedId('__dddart_receipt__', 12),
      const ScopedId('Org/雪 ?#% ', 12),
      const ScopedId('org/雪 ?#% ', 12),
    ];
    try {
      for (final id in ids) {
        await first.save(ScopedAggregate(id: id, label: id.scope));
      }
      await first.close();
      final second = repository();
      try {
        for (final id in ids) {
          expect((await second.getById(id)).label, id.scope);
        }
        await second.save(ScopedAggregate(id: ids[2], label: 'updated'));
        await second.deleteById(ids[2]);
        expect((await second.getById(ids[3])).label, ids[3].scope);
      } finally {
        await second.close();
      }
    } finally {
      await first.close();
      await factory.deleteDatabase(name);
    }
  });

  test('typed conditional atomicity, uniqueness, ABA and durable receipts',
      () async {
    final factory = createFactory();
    final name = 'typed-conditional-${UuidValue.generate()}';
    IndexedDbRepository<ScopedAggregate, ScopedId> repository() =>
        IndexedDbRepository<ScopedAggregate, ScopedId>(
          factory: factory,
          databaseName: name,
          storeName: 'aggregates',
          identityCodecs: scopedCodecs(),
          encode: encodeScoped,
          decode: decodeScoped,
        );
    var repo = repository();
    const firstId = ScopedId('one', 12);
    const secondId = ScopedId('two', 12);
    final request = ConditionalCommit<ScopedAggregate, ScopedId>(
      operationId: UuidValue.generate(),
      mutations: [
        ConditionalMutation.put(
          ScopedAggregate(id: firstId, label: 'first'),
          expected: const ExpectedRevision.absent(),
          uniqueValues: [const UniqueValue('name', 'first')],
        ),
        ConditionalMutation.put(
          ScopedAggregate(id: secondId, label: 'second'),
          expected: const ExpectedRevision.absent(),
        ),
      ],
    );
    try {
      final digest = repo.digestFor(request);
      final result = await repo.commitConditional(request);
      expect(result.decision, CommitDecision.committed);
      final Map<ScopedId, String> revisions = result.revisions;
      expect(revisions.keys, containsAll([firstId, secondId]));
      await repo.close();
      repo = repository();
      expect(
          (await repo.resolveOperation(request.operationId, digest)).revisions,
          revisions);
      expect((await repo.commitConditional(request)).revisions, revisions);
      expect(
          (await repo.findUnique(const UniqueValue('name', 'first')))
              .aggregate
              .id,
          firstId);
      final conflict = await repo.commitConditional(
        ConditionalCommit<ScopedAggregate, ScopedId>(
          operationId: UuidValue.generate(),
          mutations: [
            ConditionalMutation.put(
              ScopedAggregate(id: secondId, label: 'must not persist'),
              expected: ExpectedRevision.match(revisions[secondId]!),
              uniqueValues: [const UniqueValue('name', 'first')],
            ),
          ],
        ),
      );
      expect(conflict.rejection, CommitRejection.uniqueConflict);
      expect((await repo.getById(secondId)).label, 'second');
      await repo.commitConditional(ConditionalCommit<ScopedAggregate, ScopedId>(
        operationId: UuidValue.generate(),
        mutations: [
          ConditionalMutation.delete(firstId,
              expected: ExpectedRevision.match(revisions[firstId]!)),
        ],
      ));
      final recreated = await repo
          .commitConditional(ConditionalCommit<ScopedAggregate, ScopedId>(
        operationId: UuidValue.generate(),
        mutations: [
          ConditionalMutation.put(
            ScopedAggregate(id: firstId, label: 'recreated'),
            expected: const ExpectedRevision.absent(),
          ),
        ],
      ));
      expect(recreated.revisions[firstId], isNot(revisions[firstId]));
      final stale = await repo
          .commitConditional(ConditionalCommit<ScopedAggregate, ScopedId>(
        operationId: UuidValue.generate(),
        mutations: [
          ConditionalMutation.delete(firstId,
              expected: ExpectedRevision.match(revisions[firstId]!)),
          ConditionalMutation.delete(secondId,
              expected: ExpectedRevision.match(revisions[secondId]!)),
        ],
      ));
      expect(stale.rejection, CommitRejection.staleRevision);
      expect((await repo.getById(secondId)).label, 'second');
    } finally {
      await repo.close();
      await factory.deleteDatabase(name);
    }
  });
}
