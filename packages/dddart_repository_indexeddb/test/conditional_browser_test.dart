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

void main() {
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
    } finally {
      await first.close();
      await second.close();
      await factory.deleteDatabase(name);
    }
  });
}
