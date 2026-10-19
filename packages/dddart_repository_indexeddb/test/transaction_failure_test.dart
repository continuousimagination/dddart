import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb.dart';
import 'package:test/test.dart';

class _Sample extends AggregateRoot {
  _Sample({required this.label, super.id});

  final String label;
}

enum _Failure { none, requestAndAbort, commit }

class _Factory implements IdbFactory {
  _Factory() : database = _Database();

  final _Database database;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async =>
      database;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Database extends Database {
  _Database() : super(_UnusedFactory());

  Object? record;
  _Failure failure = _Failure.none;

  @override
  Iterable<String> get objectStoreNames => const ['samples'];

  @override
  Transaction transaction(Object storeNameOrStoreNames, String mode) =>
      _Transaction(this);

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedFactory implements IdbFactory {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Transaction implements Transaction {
  _Transaction(this.database);

  @override
  final _Database database;

  @override
  Future<Database> get completed => switch (database.failure) {
        _Failure.none => Future.value(database),
        _Failure.requestAndAbort => Future.error(StateError('aborted')),
        _Failure.commit => Future.error(StateError('commit failed')),
      };

  @override
  ObjectStore objectStore(String name) => _Store(database);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Store implements ObjectStore {
  _Store(this.database);

  final _Database database;

  @override
  Future<Object?> getObject(Object key) async => database.record;

  @override
  Future<Object> put(Object value, [Object? key]) async {
    if (database.failure == _Failure.requestAndAbort) {
      throw StateError('request failed');
    }
    if (database.failure == _Failure.none) database.record = value;
    return key!;
  }

  @override
  Future<void> delete(Object keyOrRange) async => database.record = null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  for (final failure in [_Failure.requestAndAbort, _Failure.commit]) {
    test('$failure reports one typed error and preserves committed data',
        () async {
      final factory = _Factory();
      final repository = IndexedDbRepository<_Sample>(
        factory: factory,
        databaseName: 'failure',
        storeName: 'samples',
        encode: (value) => jsonEncode({
          'id': value.id.uuid,
          'label': value.label,
        }),
        decode: (value) {
          final data = jsonDecode(value) as Map<String, dynamic>;
          return _Sample(
            id: UuidValue.fromString(data['id'] as String),
            label: data['label'] as String,
          );
        },
      );
      final first = _Sample(label: 'committed');
      await repository.save(first);
      factory.database.failure = failure;
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        await expectLater(
          repository.save(_Sample(id: first.id, label: 'uncommitted')),
          throwsA(isA<RepositoryException>().having(
            (error) => error.type,
            'type',
            RepositoryExceptionType.connection,
          )),
        );
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));
      expect(uncaught, isEmpty);
      factory.database.failure = _Failure.none;
      expect((await repository.getById(first.id)).label, 'committed');
      await repository.close();
    });
  }
}
