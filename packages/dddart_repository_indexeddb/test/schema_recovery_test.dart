import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

class _Sample extends AggregateRoot {
  _Sample({required this.name, super.id});
  final String name;
}

String _encode(_Sample value) =>
    jsonEncode({'id': value.id.uuid, 'name': value.name});

_Sample _decode(String encoded) {
  final data = jsonDecode(encoded) as Map<String, dynamic>;
  return _Sample(
    id: UuidValue.fromString(data['id'] as String),
    name: data['name'] as String,
  );
}

IndexedDbRepository<_Sample> _repository(IdbFactory factory, String name,
        {int codecVersion = 1}) =>
    IndexedDbRepository<_Sample>(
      factory: factory,
      databaseName: name,
      storeName: 'samples',
      codecVersion: codecVersion,
      encode: _encode,
      decode: _decode,
    );

class _UpgradeFaultFactory implements IdbFactory {
  _UpgradeFaultFactory(this.delegate);
  final IdbFactory delegate;
  bool failAfterMarker = true;

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
          if (failAfterMarker) {
            throw StateError('upgrade interrupted after schema marker');
          }
        },
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnavailableFactory implements IdbFactory {
  @override
  Future<Database> open(String dbName,
          {int? version,
          OnUpgradeNeededFunction? onUpgradeNeeded,
          OnBlockedFunction? onBlocked}) async =>
      throw StateError('IndexedDB unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test('interrupted version-1 upgrade rolls back marker and preserves data',
      () async {
    final factory = newIdbFactoryMemory();
    final sample = _Sample(name: 'before');
    final old = await factory.open('interrupted',
        version: 1,
        onUpgradeNeeded: (event) =>
            event.database.createObjectStore('samples'));
    final oldWrite = old.transaction('samples', idbModeReadWrite);
    final oldDone = oldWrite.completed;
    await oldWrite.objectStore('samples').put({
      'id': sample.id.uuid,
      'codecVersion': 1,
      'payload': _encode(sample),
    }, sample.id.uuid);
    await oldDone;
    old.close();

    final fault = _UpgradeFaultFactory(factory);
    final interrupted = _repository(fault, 'interrupted');
    await expectLater(
      interrupted.getById(sample.id),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.connection)),
    );
    final stillOld = await factory.open('interrupted', version: 1);
    expect(stillOld.version, 1);
    final oldRead = stillOld.transaction('samples', idbModeReadOnly);
    final oldReadDone = oldRead.completed;
    final retained =
        await oldRead.objectStore('samples').getObject(sample.id.uuid);
    final marker =
        await oldRead.objectStore('samples').getObject('__dddart_schema__');
    await oldReadDone;
    expect((retained as Map)['payload'], _encode(sample));
    expect(marker, isNull);
    stillOld.close();

    fault.failAfterMarker = false;
    final recovered = _repository(fault, 'interrupted');
    expect((await recovered.getById(sample.id)).name, 'before');
    await recovered.close();
  });

  test('two contexts reject incompatible codec without changing prior data',
      () async {
    final factory = newIdbFactoryMemory();
    final first = _repository(factory, 'codec-fence');
    final sample = _Sample(name: 'safe');
    await first.save(sample);
    final incompatible = _repository(factory, 'codec-fence', codecVersion: 2);
    await expectLater(
      incompatible.getById(sample.id),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.constraint)),
    );
    await incompatible.close();
    final restored = _repository(factory, 'codec-fence');
    expect((await restored.getById(sample.id)).name, 'safe');
    await restored.close();
  });

  test('legacy data with another codec prevents upgrade and remains intact',
      () async {
    final factory = newIdbFactoryMemory();
    final sample = _Sample(name: 'old');
    final old = await factory.open('old-codec',
        version: 1,
        onUpgradeNeeded: (event) =>
            event.database.createObjectStore('samples'));
    final write = old.transaction('samples', idbModeReadWrite);
    final done = write.completed;
    await write.objectStore('samples').put({
      'id': sample.id.uuid,
      'codecVersion': 1,
      'payload': _encode(sample),
    }, sample.id.uuid);
    await done;
    old.close();

    final incompatible = _repository(factory, 'old-codec', codecVersion: 2);
    await expectLater(
      incompatible.getById(sample.id),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.constraint)),
    );
    final retained = await factory.open('old-codec', version: 1);
    expect(retained.version, 1);
    final read = retained.transaction('samples', idbModeReadOnly);
    final readDone = read.completed;
    final raw = await read.objectStore('samples').getObject(sample.id.uuid);
    await readDone;
    expect((raw as Map)['payload'], _encode(sample));
    retained.close();
    await incompatible.close();
  });

  test('malformed and old records cannot be silently overwritten or deleted',
      () async {
    final factory = newIdbFactoryMemory();
    final repository = _repository(factory, 'write-fence');
    final sample = _Sample(name: 'safe');
    await repository.save(sample);
    final raw = await factory.open('write-fence', version: 2);
    final write = raw.transaction('samples', idbModeReadWrite);
    final done = write.completed;
    await write.objectStore('samples').put({
      'id': sample.id.uuid,
      'codecVersion': 0,
      'payload': _encode(sample),
      'revision': 'unrecognized',
    }, sample.id.uuid);
    await done;
    raw.close();
    final guarded = _repository(factory, 'write-fence');
    await expectLater(
      guarded.save(_Sample(id: sample.id, name: 'replacement')),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.constraint)),
    );
    await expectLater(
      guarded.deleteById(sample.id),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.constraint)),
    );
    final check = await factory.open('write-fence', version: 2);
    final read = check.transaction('samples', idbModeReadOnly);
    final readDone = read.completed;
    final retained =
        await read.objectStore('samples').getObject(sample.id.uuid);
    await readDone;
    expect((retained as Map)['codecVersion'], 0);
    check.close();
    await guarded.close();
    await repository.close();
  });

  test('undecodable or misidentified payloads survive basic CRUD attempts',
      () async {
    for (final invalid in [
      'not JSON',
      _encode(_Sample(name: 'wrong identity')),
    ]) {
      final factory = newIdbFactoryMemory();
      final sample = _Sample(name: 'original');
      final seeded = _repository(factory, 'bad-payload');
      await seeded.save(sample);
      final raw = await factory.open('bad-payload', version: 2);
      final write = raw.transaction('samples', idbModeReadWrite);
      final done = write.completed;
      await write.objectStore('samples').put({
        'id': sample.id.uuid,
        'codecVersion': 1,
        'payload': invalid,
      }, sample.id.uuid);
      await done;
      raw.close();
      final guarded = _repository(factory, 'bad-payload');
      await expectLater(
        guarded.save(_Sample(id: sample.id, name: 'replacement')),
        throwsA(isA<RepositoryException>().having(
            (error) => error.type, 'type', RepositoryExceptionType.constraint)),
      );
      await expectLater(
        guarded.deleteById(sample.id),
        throwsA(isA<RepositoryException>().having(
            (error) => error.type, 'type', RepositoryExceptionType.constraint)),
      );
      final check = await factory.open('bad-payload', version: 2);
      final read = check.transaction('samples', idbModeReadOnly);
      final readDone = read.completed;
      final retained =
          await read.objectStore('samples').getObject(sample.id.uuid);
      await readDone;
      expect((retained as Map)['payload'], invalid);
      check.close();
    }
  });

  test('unavailable storage reports a typed connection error', () async {
    final repository = _repository(_UnavailableFactory(), 'unavailable');
    await expectLater(
      repository.getById(UuidValue.generate()),
      throwsA(isA<RepositoryException>().having(
          (error) => error.type, 'type', RepositoryExceptionType.connection)),
    );
    await repository.close();
  });
}
