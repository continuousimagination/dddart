import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb.dart';
import 'package:test/test.dart';

class _Sample extends UuidAggregateRoot {}

class _BlockedEvent implements Event {}

class _PendingFactory implements IdbFactory {
  final result = Completer<Database>();
  OnBlockedFunction? blocked;
  int opens = 0;

  @override
  Future<Database> open(String name,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) {
    opens++;
    blocked = onBlocked;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// A late connection must be closed without ever starting a data transaction.
class _LateDatabase implements Database {
  final closed = Completer<void>();

  @override
  void close() => closed.complete();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

IndexedDbRepository<_Sample, UuidValue> _repository(IdbFactory factory) =>
    IndexedDbRepository<_Sample, UuidValue>(
      factory: factory,
      databaseName: 'lifecycle',
      storeName: 'samples',
      encode: (_) => throw UnimplementedError(),
      decode: (_) => throw UnimplementedError(),
    );

void main() {
  test('blocked open closes a late connection without dispatching a read',
      () async {
    final factory = _PendingFactory();
    final repository = _repository(factory);
    final failed = expectLater(repository.getById(UuidValue.generate()),
        throwsA(isA<IndexedDbOpenBlockedException>()));
    factory.blocked!(_BlockedEvent());
    await failed;
    await expectLater(repository.getById(UuidValue.generate()),
        throwsA(isA<IndexedDbOpenBlockedException>()));
    expect(factory.opens, 1);
    final late = _LateDatabase();
    factory.result.complete(late);
    await late.closed.future;
    await repository.close();
  });

  test('late native failure after blocked open is observed', () async {
    final factory = _PendingFactory();
    final repository = _repository(factory);
    final failed = expectLater(repository.getById(UuidValue.generate()),
        throwsA(isA<IndexedDbOpenBlockedException>()));
    factory.blocked!(_BlockedEvent());
    await failed;
    factory.result.completeError(StateError('abandoned native open aborted'));
    // Pump the event queue so any unobserved error fails this test.
    await Future<void>.delayed(Duration.zero);
    await repository.close();
  });

  test('close settles a pending open and closes a late connection', () async {
    final factory = _PendingFactory();
    final repository = _repository(factory);
    final failed = expectLater(
        repository.getById(UuidValue.generate()),
        throwsA(isA<RepositoryException>().having((error) => error.type, 'type',
            RepositoryExceptionType.connection)));
    await repository.close();
    await failed;
    final late = _LateDatabase();
    factory.result.complete(late);
    await late.closed.future;
    await repository.close();
    expect(factory.opens, 1);
  });
}
