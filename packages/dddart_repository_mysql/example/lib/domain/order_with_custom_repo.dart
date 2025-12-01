import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:dddart_repository_mysql_example/domain/address.dart';
import 'package:dddart_repository_mysql_example/domain/money.dart';
import 'package:dddart_repository_mysql_example/domain/order_item.dart';
import 'package:dddart_repository_mysql_example/domain/order_repository.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'order_with_custom_repo.g.dart';
part 'order_with_custom_repo_impl.dart';

/// Order aggregate with custom repository interface.
///
/// This demonstrates how to use a custom repository interface that will
/// generate an abstract base class requiring custom method implementations.
@Serializable()
@GenerateMysqlRepository(
  tableName: 'orders_custom',
  implements: OrderRepository,
)
class OrderWithCustomRepo extends AggregateRoot {
  /// Creates a new Order aggregate.
  OrderWithCustomRepo({
    required this.customerName,
    required this.shippingAddress,
    required this.items,
    this.billingAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name of the customer placing the order.
  final String customerName;

  /// Shipping address for the order.
  final Address shippingAddress;

  /// Optional billing address (if different from shipping).
  final Address? billingAddress;

  /// List of items in the order.
  final List<OrderItem> items;

  /// Calculates the total amount for the order.
  Money get totalAmount {
    if (items.isEmpty) {
      return const Money(amount: 0, currency: 'USD');
    }

    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice.amount,
    );

    return Money(amount: total, currency: items.first.unitPrice.currency);
  }
}
