@TestOn('browser')
library;

import 'dart:async';
import 'package:idb_shim/idb_client_native.dart';
import 'package:dddart_repository_indexeddb/src/transaction_error_guard_web.dart';
import 'package:test/test.dart';

void main() {
  test('native duplicate request error has one observed completion failure',
      () async {
    final factory = idbFactoryNative;
    final name = 'dddart-native-error-${DateTime.now().microsecondsSinceEpoch}';
    final db = await factory.open(name,
        version: 1,
        onUpgradeNeeded: (event) =>
            event.database.createObjectStore('samples'));
    try {
      final first = db.transaction('samples', idbModeReadWrite);
      final firstDone = first.completed;
      await first.objectStore('samples').add({'value': 1}, 'same');
      await firstDone;

      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final duplicate = db.transaction('samples', idbModeReadWrite);
        final completion = duplicate.completed;
        guardNativeTransactionError(duplicate);
        await expectLater(
            duplicate.objectStore('samples').add({'value': 2}, 'same'),
            throwsA(anything));
        await expectLater(completion, throwsA(anything));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, _) => uncaught.add(error));
      expect(uncaught, isEmpty);
      final read = db.transaction('samples', idbModeReadOnly);
      final readDone = read.completed;
      expect(
          (await read.objectStore('samples').getObject('same') as Map)['value'],
          1);
      await readDone;
    } finally {
      db.close();
      await factory.deleteDatabase(name);
    }
  });
}
