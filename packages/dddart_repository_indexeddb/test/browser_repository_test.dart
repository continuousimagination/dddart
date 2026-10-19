@TestOn('browser')
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

class _BrowserSample extends AggregateRoot {
  _BrowserSample({required this.label, super.id});

  final String label;
}

void main() {
  test('real IndexedDB persists detached CRUD across connections', () async {
    final factory = idbFactoryNative;
    final databaseName = 'dddart-browser-${UuidValue.generate()}';
    IndexedDbRepository<_BrowserSample> repository() =>
        IndexedDbRepository<_BrowserSample>(
          factory: factory,
          databaseName: databaseName,
          storeName: 'samples',
          encode: (value) => jsonEncode({
            'id': value.id.uuid,
            'label': value.label,
          }),
          decode: (value) {
            final data = jsonDecode(value) as Map<String, dynamic>;
            return _BrowserSample(
              id: UuidValue.fromString(data['id'] as String),
              label: data['label'] as String,
            );
          },
        );

    final first = repository();
    final sample = _BrowserSample(label: 'original');
    try {
      await first.save(sample);
      expect((await first.getById(sample.id)).label, 'original');
      await first.close();

      final second = repository();
      try {
        expect((await second.getById(sample.id)).label, 'original');
        await second.save(_BrowserSample(id: sample.id, label: 'updated'));
        expect((await second.getById(sample.id)).label, 'updated');

        final db = await factory.open(databaseName, version: 1);
        try {
          final transaction = db.transaction('samples', idbModeReadWrite);
          final committed = transaction.completed;
          await transaction.objectStore('samples').put({
            'id': sample.id.uuid,
            'codecVersion': 99,
            'payload': 'not a supported record',
          }, sample.id.uuid);
          await committed;
        } finally {
          db.close();
        }
        await expectLater(
          second.getById(sample.id),
          throwsA(isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.constraint,
          )),
        );
        // A failed read must leave the original stored bytes in place.
        final raw = await factory.open(databaseName, version: 1);
        try {
          final transaction = raw.transaction('samples', idbModeReadOnly);
          final committed = transaction.completed;
          final stored = await transaction
              .objectStore('samples')
              .getObject(sample.id.uuid) as Map;
          await committed;
          expect(stored['codecVersion'], 99);
        } finally {
          raw.close();
        }

        await second.deleteById(sample.id);
        await expectLater(
          second.getById(sample.id),
          throwsA(isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.notFound,
          )),
        );
      } finally {
        await second.close();
      }
    } finally {
      await first.close();
      await factory.deleteDatabase(databaseName);
    }
  });
}
