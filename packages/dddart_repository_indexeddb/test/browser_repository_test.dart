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

class _InterruptedUpgradeFactory implements IdbFactory {
  _InterruptedUpgradeFactory(this.delegate);

  final IdbFactory delegate;

  @override
  Future<Database> open(String dbName,
          {int? version,
          OnUpgradeNeededFunction? onUpgradeNeeded,
          OnBlockedFunction? onBlocked}) =>
      delegate.open(
        dbName,
        version: version,
        onBlocked: onBlocked,
        onUpgradeNeeded: (event) async {
          await onUpgradeNeeded?.call(event);
          event.transaction.abort();
        },
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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

        final db = await factory.open(databaseName, version: 2);
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
        final raw = await factory.open(databaseName, version: 2);
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

        await expectLater(
          second.deleteById(sample.id),
          throwsA(isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.constraint,
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

  test('real IndexedDB rejects incompatible codec in another connection',
      () async {
    final factory = idbFactoryNative;
    final name = 'dddart-browser-codec-${UuidValue.generate()}';
    IndexedDbRepository<_BrowserSample> repository(int codecVersion) =>
        IndexedDbRepository<_BrowserSample>(
          factory: factory,
          databaseName: name,
          storeName: 'samples',
          codecVersion: codecVersion,
          encode: (value) =>
              jsonEncode({'id': value.id.uuid, 'label': value.label}),
          decode: (value) {
            final data = jsonDecode(value) as Map<String, dynamic>;
            return _BrowserSample(
              id: UuidValue.fromString(data['id'] as String),
              label: data['label'] as String,
            );
          },
        );
    final first = repository(1);
    final incompatible = repository(2);
    final sample = _BrowserSample(label: 'preserved');
    try {
      await first.save(sample);
      await expectLater(
        incompatible.getById(sample.id),
        throwsA(isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.constraint,
        )),
      );
      expect((await first.getById(sample.id)).label, 'preserved');
    } finally {
      await first.close();
      await incompatible.close();
      await factory.deleteDatabase(name);
    }
  });

  test('real IndexedDB upgrades version-1 records without rewriting them',
      () async {
    final factory = idbFactoryNative;
    final name = 'dddart-browser-upgrade-${UuidValue.generate()}';
    final sample = _BrowserSample(label: 'legacy');
    final payload = jsonEncode({'id': sample.id.uuid, 'label': sample.label});
    final old = await factory.open(name,
        version: 1,
        onUpgradeNeeded: (event) =>
            event.database.createObjectStore('samples'));
    final write = old.transaction('samples', idbModeReadWrite);
    final done = write.completed;
    await write.objectStore('samples').put({
      'id': sample.id.uuid,
      'codecVersion': 1,
      'payload': payload,
    }, sample.id.uuid);
    await done;
    old.close();
    final interrupted = IndexedDbRepository<_BrowserSample>(
      factory: _InterruptedUpgradeFactory(factory),
      databaseName: name,
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
    await expectLater(
      interrupted.getById(sample.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.connection,
      )),
    );
    final prior = await factory.open(name, version: 1);
    try {
      expect(prior.version, 1);
      final read = prior.transaction('samples', idbModeReadOnly);
      final readDone = read.completed;
      final retained =
          await read.objectStore('samples').getObject(sample.id.uuid);
      final marker =
          await read.objectStore('samples').getObject('__dddart_schema__');
      await readDone;
      expect((retained as Map)['payload'], payload);
      expect(marker, isNull);
    } finally {
      prior.close();
    }
    final incompatible = IndexedDbRepository<_BrowserSample>(
      factory: factory,
      databaseName: name,
      storeName: 'samples',
      codecVersion: 2,
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
    await expectLater(
      incompatible.getById(sample.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    final repository = IndexedDbRepository<_BrowserSample>(
      factory: factory,
      databaseName: name,
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
    try {
      expect((await repository.getById(sample.id)).label, 'legacy');
      final upgraded = await factory.open(name, version: 2);
      try {
        final read = upgraded.transaction('samples', idbModeReadOnly);
        final readDone = read.completed;
        final raw = await read.objectStore('samples').getObject(sample.id.uuid);
        await readDone;
        expect((raw as Map)['payload'], payload);
      } finally {
        upgraded.close();
      }
    } finally {
      await repository.close();
      await factory.deleteDatabase(name);
    }
  });
}
