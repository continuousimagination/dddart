import 'dart:async';

import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

void main() {
  for (final failure in ['begin', 'commit', 'rollback']) {
    test('$failure failure releases the queue and invalidates the driver',
        () async {
      final coordinator = SqlConnectionCoordinator();
      final calls = <String>[];
      final original = StateError(failure == 'rollback' ? 'action' : failure);
      Future<void> command(String name) async {
        calls.add(name);
        if (name == failure) throw original;
      }

      await expectLater(
        coordinator.transaction(
          action: () async {
            if (failure == 'rollback') throw original;
          },
          begin: () => command('begin'),
          commit: () => command('commit'),
          rollback: () => command('rollback'),
          invalidate: () => command('invalidate'),
        ),
        throwsA(same(original)),
      );
      expect(calls.last, 'invalidate');
      expect(await coordinator.run(() async => 42), 42);
    });
  }

  test('escaped work cannot inherit a completed transaction owner', () async {
    final coordinator = SqlConnectionCoordinator();
    final release = Completer<void>();
    late Future<void> escaped;
    await coordinator.transaction(
      action: () async {
        escaped = release.future.then((_) => coordinator.run(() async {}));
      },
      begin: () async {},
      commit: () async {},
      rollback: () async {},
      invalidate: () async {},
    );
    final checked = expectLater(escaped, throwsStateError);
    release.complete();
    await checked;
    expect(await coordinator.run(() async => 1), 1);
  });
}
