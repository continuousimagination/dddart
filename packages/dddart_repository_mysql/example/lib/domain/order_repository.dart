import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql_example/domain/order_with_custom_repo.dart';

/// Custom repository interface for Order with domain-specific query methods.
abstract class OrderRepository implements Repository<OrderWithCustomRepo> {
  /// Finds all orders for a specific customer.
  Future<List<OrderWithCustomRepo>> findByCustomerName(String customerName);

  /// Finds orders with a total amount greater than the specified value.
  Future<List<OrderWithCustomRepo>> findByMinimumAmount(double minAmount);
}
