import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:test/test.dart';

class _Sample extends AggregateRoot {
  _Sample({required this.name, super.id});

  String name;
}

String _encode(_Sample value) => jsonEncode({
      'id': value.id.uuid,
      'name': value.name,
    });

_Sample _decode(String value) {
  final data = jsonDecode(value) as Map<String, dynamic>;
  return _Sample(
    id: UuidValue.fromString(data['id'] as String),
    name: data['name'] as String,
  );
}

void main() {
  test('CRUD writes detached snapshots and survives a repository reopen',
      () async {
    final factory = newIdbFactoryMemory();
    IndexedDbRepository<_Sample> repository() => IndexedDbRepository<_Sample>(
          factory: factory,
          databaseName: 'crud',
          storeName: 'samples',
          encode: _encode,
          decode: _decode,
        );

    final first = repository();
    final source = _Sample(name: 'before');
    await first.save(source);
    source.name = 'after';
    final stored = await first.getById(source.id);
    expect(stored.name, 'before');
    stored.name = 'local change';
    expect((await first.getById(source.id)).name, 'before');
    await first.close();

    final reopened = repository();
    expect((await reopened.getById(source.id)).name, 'before');
    await reopened.save(_Sample(id: source.id, name: 'replacement'));
    expect((await reopened.getById(source.id)).name, 'replacement');
    await reopened.deleteById(source.id);
    await expectLater(
      reopened.getById(source.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.notFound,
      )),
    );
    await expectLater(
      reopened.deleteById(source.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.notFound,
      )),
    );
    await reopened.close();
  });

  test('codec failure preserves the prior record and corrupt data is explicit',
      () async {
    final factory = newIdbFactoryMemory();
    final source = _Sample(name: 'good');
    final repository = IndexedDbRepository<_Sample>(
      factory: factory,
      databaseName: 'failures',
      storeName: 'samples',
      encode: (value) {
        if (value.name == 'bad') throw const FormatException('bad');
        return _encode(value);
      },
      decode: _decode,
    );
    await repository.save(source);
    await expectLater(
      repository.save(_Sample(id: source.id, name: 'bad')),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    expect((await repository.getById(source.id)).name, 'good');

    final db = await factory.open('failures', version: 2);
    final transaction = db.transaction('samples', idbModeReadWrite);
    final committed = transaction.completed;
    await transaction.objectStore('samples').put({
      'id': source.id.uuid,
      'codecVersion': 99,
      'payload': _encode(source),
    }, source.id.uuid);
    await committed;
    await expectLater(
      repository.getById(source.id),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.constraint,
      )),
    );
    db.close();
    await repository.close();
  });

  test('closed repository rejects new reads as a connection failure', () async {
    final repository = IndexedDbRepository<_Sample>(
      factory: newIdbFactoryMemory(),
      databaseName: 'closed',
      storeName: 'samples',
      encode: _encode,
      decode: _decode,
    );
    await repository.close();
    await expectLater(
      repository.getById(UuidValue.generate()),
      throwsA(isA<RepositoryException>().having(
        (error) => error.type,
        'type',
        RepositoryExceptionType.connection,
      )),
    );
  });
}
