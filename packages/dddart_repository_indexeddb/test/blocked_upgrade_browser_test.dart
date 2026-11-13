@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _Sample extends UuidAggregateRoot {
  _Sample({required this.name, super.id});
  final String name;
}

String _encode(_Sample sample) =>
    jsonEncode({'id': sample.id.uuid, 'name': sample.name});

_Sample _decode(String payload) {
  final data = jsonDecode(payload) as Map<String, dynamic>;
  return _Sample(
    id: UuidValue.fromString(data['id'] as String),
    name: data['name'] as String,
  );
}

IndexedDbRepository<_Sample, UuidValue> _repository(
  String name, {
  IdbFactory? factory,
  int codecVersion = 1,
}) =>
    IndexedDbRepository<_Sample, UuidValue>(
      factory: factory ?? idbFactoryNative,
      databaseName: name,
      storeName: 'samples',
      codecVersion: codecVersion,
      encode: _encode,
      decode: _decode,
    );

// Observe the native request settling even though the public operation has
// already failed. This is a native factory, not a fake blocked event.
class _ObservedFactory implements IdbFactory {
  Future<void>? settled;
  int opens = 0;

  @override
  Future<Database> open(String name,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) {
    opens++;
    final pending = idbFactoryNative.open(name,
        version: version,
        onUpgradeNeeded: onUpgradeNeeded,
        onBlocked: onBlocked);
    settled = pending.then<void>((_) {}, onError: (Object _) {});
    return pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// A same-origin iframe owns the old native connection in a separate browser
// global. Commands and acknowledgements cross postMessage; no connection or
// transaction object is shared with the parent test context.
class _LegacyContext {
  final frame = web.HTMLIFrameElement()..srcdoc = _legacyDocument.toJS;
  final _replies = <int, Completer<Object?>>{};
  int _nextId = 0;
  late final JSFunction _listener;

  Future<void> start() async {
    final loaded = Completer<void>();
    frame.addEventListener('load', ((web.Event _) => loaded.complete()).toJS,
        web.AddEventListenerOptions(once: true));
    _listener = ((web.MessageEvent event) {
      if (event.source != frame.contentWindow) return;
      final reply = event.data.dartify() as Map;
      final completer = _replies.remove(reply['id']);
      if (reply.containsKey('error')) {
        completer?.completeError(StateError(reply['error'] as String));
      } else {
        completer?.complete(reply['value']);
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    web.document.body!.append(frame);
    await loaded.future;
  }

  Future<Object?> call(String command, [Map<String, Object?>? args]) {
    final id = _nextId++;
    final reply = Completer<Object?>();
    _replies[id] = reply;
    frame.contentWindow!.postMessage(
        {'id': id, 'command': command, ...?args}.jsify(), '*'.toJS);
    return reply.future.timeout(const Duration(seconds: 5));
  }

  void dispose() {
    web.window.removeEventListener('message', _listener);
    frame.remove();
  }
}

const _legacyDocument = r'''
<!doctype html><script>
let db;
let versionChanges = 0;
window.addEventListener('message', async event => {
  const {id, command, name, records} = event.data;
  try {
    let value = null;
    if (command === 'seed') {
      db = await new Promise((resolve, reject) => {
        const request = indexedDB.open(name, 1);
        request.onupgradeneeded = () => request.result.createObjectStore('samples');
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      // Deliberately model an older app that does not release the connection.
      db.onversionchange = () => versionChanges++;
      await new Promise((resolve, reject) => {
        const tx = db.transaction('samples', 'readwrite');
        for (const [key, record] of Object.entries(records)) {
          tx.objectStore('samples').put(record, key);
        }
        tx.oncomplete = resolve;
        tx.onabort = () => reject(tx.error);
      });
    } else if (command === 'snapshot') {
      const entries = await new Promise((resolve, reject) => {
        const values = {};
        const tx = db.transaction('samples', 'readonly');
        const request = tx.objectStore('samples').openCursor();
        request.onsuccess = () => {
          const cursor = request.result;
          if (cursor) { values[cursor.key] = cursor.value; cursor.continue(); }
        };
        tx.oncomplete = () => resolve(values);
        tx.onabort = () => reject(tx.error);
      });
      value = {version: db.version, records: entries, versionChanges};
    } else if (command === 'close') {
      db.close();
      db = null;
    } else { throw new Error('Unknown command'); }
    event.source.postMessage({id, value}, event.origin);
  } catch (error) {
    event.source.postMessage({id, error: String(error)}, event.origin);
  }
});
</script>
''';

Future<Map<String, Object?>> _records(Database db) async {
  final tx = db.transaction('samples', idbModeReadOnly);
  final done = tx.completed;
  final entries = <String, Object?>{};
  await for (final cursor
      in tx.objectStore('samples').openCursor(autoAdvance: true)) {
    entries[cursor.primaryKey as String] = cursor.value;
  }
  await done;
  return entries;
}

void main() {
  test('blocked cross-context upgrade abandons safely and retries atomically',
      () async {
    final name = 'dddart-blocked-${UuidValue.generate()}';
    final basic = _Sample(name: 'legacy basic');
    final managed = _Sample(name: 'legacy managed');
    final operationId = UuidValue.generate();
    final revision = UuidValue.generate().uuid;
    final uniqueKey = '__dddart_unique__${base64Url.encode(utf8.encode(
      jsonEncode(['name', 'legacy managed']),
    ))}';
    final records = <String, Object?>{
      basic.id.uuid: {
        'id': basic.id.uuid,
        'codecVersion': 1,
        'payload': _encode(basic),
      },
      managed.id.uuid: {
        'id': managed.id.uuid,
        'codecVersion': 1,
        'payload': _encode(managed),
        'managed': true,
        'revision': revision,
        'uniqueKeys': [uniqueKey],
      },
      uniqueKey: {'kind': 'unique', 'owner': managed.id.uuid},
      '__dddart_receipt__${operationId.uuid}': {
        'kind': 'receipt',
        'digest': 'legacy-digest',
        'decision': 'committed',
        'rejection': null,
        'revisions': {managed.id.uuid: revision},
      },
      '__dddart_receipt_count__': {'kind': 'receiptCount', 'count': 1},
    };
    final old = _LegacyContext();
    final factory = _ObservedFactory();
    final repository = _repository(name, factory: factory);
    await old.start();
    try {
      await old.call('seed', {'name': name, 'records': records});
      final blocked = throwsA(isA<IndexedDbOpenBlockedException>()
          .having(
              (error) => error.type, 'type', RepositoryExceptionType.connection)
          .having((error) => error.databaseName, 'database', name));
      // Reads, writes and conditional commits share the same failed open;
      // no operation may reach a data transaction after the blocked event.
      await Future.wait([
        expectLater(repository.getById(basic.id), blocked),
        expectLater(
            repository.save(_Sample(id: basic.id, name: 'changed')), blocked),
        expectLater(
            repository.commitConditional(ConditionalCommit(
              operationId: UuidValue.generate(),
              mutations: [
                ConditionalMutation.put(_Sample(name: 'new'),
                    expected: ExpectedRevision.absent()),
              ],
            )),
            blocked),
      ]).timeout(const Duration(seconds: 5));
      final snapshot = await old.call('snapshot') as Map;
      expect(snapshot['version'], 1);
      expect(snapshot['versionChanges'], 1);
      expect(snapshot['records'], records); // Also proves marker is absent.

      // An immediate retry must not silently queue behind the abandoned
      // request, where IndexedDB would deliver no second blocked event.
      await expectLater(repository.getById(basic.id), blocked);
      expect(factory.opens, 1);
      expect((await old.call('snapshot') as Map)['records'], records);

      await old.call('close');
      await factory.settled!.timeout(const Duration(seconds: 5));
      // The abandoned request must abort, not upgrade later in the background.
      final stillOld = await idbFactoryNative.open(name, version: 1);
      expect(stillOld.version, 1);
      expect(await _records(stillOld), records);
      stillOld.close();

      // Retry on the SAME repository now performs a fresh atomic upgrade.
      expect((await repository.getById(basic.id)).name, basic.name);
      final raw = await idbFactoryNative.open(name, version: 2);
      expect(raw.version, 2);
      expect(await _records(raw), {
        ...records,
        '__dddart_schema__': {
          'kind': 'schema',
          'version': 2,
          'codecVersion': 1,
        },
      });
      raw.close();
      expect((await repository.getVersioned(managed.id)).revision, revision);
      expect(
          (await repository
                  .findUnique(const UniqueValue('name', 'legacy managed')))
              .aggregate
              .id,
          managed.id);
      expect(
          (await repository.resolveOperation(operationId, 'legacy-digest'))
              .revisions[managed.id],
          revision);

      final incompatible = _repository(name, codecVersion: 2);
      await expectLater(
          incompatible.getById(basic.id),
          throwsA(isA<RepositoryException>().having((error) => error.type,
              'type', RepositoryExceptionType.constraint)));
      await incompatible.close();
      await expectLater(
          idbFactoryNative.open(name, version: 1), throwsA(anything));
      final compatible = _repository(name);
      expect((await compatible.getById(basic.id)).name, basic.name);
      await compatible.close();
      final unchanged = await idbFactoryNative.open(name, version: 2);
      final afterFence = await _records(unchanged);
      expect(afterFence.length, records.length + 1);
      for (final entry in records.entries) {
        expect(afterFence[entry.key], entry.value);
      }
      unchanged.close();
    } finally {
      old.dispose();
      await repository.close();
      await idbFactoryNative.deleteDatabase(name);
    }
  });

  test('close abandons a queued native open before it can upgrade', () async {
    final name = 'dddart-close-open-${UuidValue.generate()}';
    final sample = _Sample(name: 'unchanged');
    final records = <String, Object?>{
      sample.id.uuid: {
        'id': sample.id.uuid,
        'codecVersion': 1,
        'payload': _encode(sample),
      },
    };
    final old = _LegacyContext();
    final factory = _ObservedFactory();
    final repository = _repository(name, factory: factory);
    await old.start();
    try {
      await old.call('seed', {'name': name, 'records': records});
      final operation = expectLater(
          repository.getById(sample.id),
          throwsA(isA<RepositoryException>().having((error) => error.type,
              'type', RepositoryExceptionType.connection)));
      // Do not wait for blocked: close must settle even a still-queued request.
      await repository.close().timeout(const Duration(seconds: 5));
      await operation;
      expect((await old.call('snapshot') as Map)['records'], records);
      await old.call('close');
      await factory.settled!.timeout(const Duration(seconds: 5));
      final retained = await idbFactoryNative.open(name, version: 1);
      expect(retained.version, 1);
      expect(await _records(retained), records);
      retained.close();
      await expectLater(
          repository.getById(sample.id),
          throwsA(isA<RepositoryException>().having(
              (error) => error.message, 'message', contains('closed'))));
      await repository.close();
    } finally {
      old.dispose();
      await repository.close();
      await idbFactoryNative.deleteDatabase(name);
    }
  });

  test('adapter releases version-change connection and rejects further use',
      () async {
    final name = 'dddart-version-change-${UuidValue.generate()}';
    final repository = _repository(name);
    final sample = _Sample(name: 'preserved');
    await repository.save(sample);
    var blocked = false;
    final upgraded = await idbFactoryNative
        .open(name, version: 3, onBlocked: (_) => blocked = true)
        .timeout(const Duration(seconds: 5));
    try {
      expect(blocked, isFalse);
      expect((await _records(upgraded))[sample.id.uuid], {
        'id': sample.id.uuid,
        'codecVersion': 1,
        'payload': _encode(sample),
      });
      await expectLater(
          repository.getById(sample.id),
          throwsA(isA<RepositoryException>()
              .having((error) => error.type, 'type',
                  RepositoryExceptionType.connection)
              .having((error) => error.message, 'message',
                  contains('version change'))));
      await expectLater(
          _repository(name).getById(sample.id),
          throwsA(isA<RepositoryException>().having((error) => error.type,
              'type', RepositoryExceptionType.connection)));
    } finally {
      upgraded.close();
      await repository.close();
      await idbFactoryNative.deleteDatabase(name);
    }
  });

  test('adapter releases its connection for database deletion', () async {
    final name = 'dddart-delete-version-change-${UuidValue.generate()}';
    final repository = _repository(name);
    final sample = _Sample(name: 'before deletion');
    await repository.save(sample);
    var blocked = false;
    try {
      await idbFactoryNative
          .deleteDatabase(name, onBlocked: (_) => blocked = true)
          .timeout(const Duration(seconds: 5));
      expect(blocked, isFalse);
      await expectLater(
          repository.save(sample),
          throwsA(isA<RepositoryException>()
              .having((error) => error.type, 'type',
                  RepositoryExceptionType.connection)
              .having((error) => error.message, 'message',
                  contains('version change'))));
    } finally {
      await repository.close();
      await idbFactoryNative.deleteDatabase(name);
    }
  });
}
