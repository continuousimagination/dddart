import 'dart:async';

import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

/// Runs the same connection ownership contract on each physical SQL driver.
void transactionOwnershipContract(SqlConnection Function() create) {
  late SqlConnection db;
  late String table;
  setUp(() async {
    db = create();
    await db.open();
    table = 'ownership_${DateTime.now().microsecondsSinceEpoch}';
    await db.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY)');
  });
  tearDown(() async {
    await db.open();
    await db.execute('DROP TABLE IF EXISTS $table');
    await db.close();
  });

  for (final failFirst in [false, true]) {
    for (final failSecond in [false, true]) {
      test('independent transactions: rollback A=$failFirst B=$failSecond',
          () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final first = db.transaction(() async {
          await db.execute('INSERT INTO $table VALUES (1)');
          entered.complete();
          await release.future;
          if (failFirst) throw StateError('A');
        });
        final checkedFirst =
            failFirst ? expectLater(first, throwsStateError) : first;
        await entered.future;
        final second = db.transaction(() async {
          expect(
            release.isCompleted,
            isTrue,
            reason: 'B must not enter the transaction owned by A',
          );
          await db.execute('INSERT INTO $table VALUES (2)');
          if (failSecond) throw StateError('B');
        });
        final checkedSecond =
            failSecond ? expectLater(second, throwsStateError) : second;
        release.complete();
        await Future.wait([checkedFirst, checkedSecond]).timeout(
          const Duration(seconds: 10),
        );
        expect(
          (await db.query('SELECT id FROM $table ORDER BY id'))
              .map((row) => row['id']),
          [if (!failFirst) 1, if (!failSecond) 2],
        );
      });
    }
  }

  test('independent reads and writes wait for an owning rollback', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = db.transaction(() async {
      await db.execute('INSERT INTO $table VALUES (1)');
      entered.complete();
      await release.future;
      throw StateError('rollback');
    });
    final checked = expectLater(first, throwsStateError);
    await entered.future;
    final read = db.query('SELECT id FROM $table');
    final write = db.execute('INSERT INTO $table VALUES (2)');
    release.complete();
    await checked;
    expect(await read, isEmpty);
    await write;
    expect((await db.query('SELECT id FROM $table')).single['id'], 2);
  });

  test('nested success joins; caught nested failure rolls back all work',
      () async {
    await db.transaction(() async {
      await db.transaction(() => db.execute('INSERT INTO $table VALUES (1)'));
    });
    await expectLater(
      db.transaction(() async {
        await db.execute('INSERT INTO $table VALUES (2)');
        try {
          await db.transaction(() async {
            await db.execute('INSERT INTO $table VALUES (3)');
            throw Exception('inner');
          });
        } on Exception {
          // Catching the exception does not turn the outer transaction into success.
        }
      }),
      throwsA(isA<SqlTransactionRolledBack>()),
    );
    expect((await db.query('SELECT id FROM $table')).single['id'], 1);
  });

  test('close queues behind active work and queued commands fail cleanly',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = db.transaction(() async {
      entered.complete();
      await release.future;
      await db.execute('INSERT INTO $table VALUES (1)');
    });
    await entered.future;
    final close = db.close();
    final rejected = expectLater(db.query('SELECT 1'), throwsStateError);
    release.complete();
    await first;
    await close;
    await rejected;
    expect(db.isOpen, isFalse);
  });

  test('close in a transaction is rejected without destroying its connection',
      () async {
    await db.transaction(() async {
      await expectLater(db.close(), throwsStateError);
      await db.execute('INSERT INTO $table VALUES (1)');
    });
    expect((await db.query('SELECT id FROM $table')).single['id'], 1);
  });
}
