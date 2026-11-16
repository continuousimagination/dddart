import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:test/test.dart';

import '../../dddart_repository_sql/test/transaction_ownership_contract.dart';
import 'test_models.dart';

void main() {
  transactionOwnershipContract(SqliteConnection.memory);
  test('generated aggregate graph survives an unrelated transaction rollback',
      () async {
    final db = SqliteConnection.memory();
    await db.open();
    addTearDown(db.close);
    final repository = OrderSqliteRepository(db);
    await repository.createTables();
    Order order() => Order(
          customerId: UuidValue.generate(),
          totalAmount: const Money(amount: 10, currency: 'USD'),
          shippingAddress: const Address(street: 'A', city: 'B', country: 'C'),
          items: [
            OrderItem(
              productId: UuidValue.generate(),
              quantity: 1,
              price: const Money(amount: 10, currency: 'USD'),
            ),
          ],
        );
    final first = order();
    final second = order();
    final entered = Completer<void>();
    final release = Completer<void>();
    final failing = db.transaction(() async {
      await repository.save(first);
      entered.complete();
      await release.future;
      throw StateError('rollback');
    });
    final checked = expectLater(failing, throwsStateError);
    await entered.future;
    final saved = repository.save(second);
    release.complete();
    await checked;
    await saved;
    final loaded = await repository.getById(second.id);
    expect(loaded.items.single.id, second.items.single.id);
    await expectLater(
      repository.getById(first.id),
      throwsA(isA<RepositoryException>()),
    );
  });
}
