import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mysql_example/domain/money.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'order_item.g.dart';

/// Entity representing an item in an order.
@Serializable()
class OrderItem extends Entity {
  /// Creates a new OrderItem entity.
  OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name of the product.
  final String productName;

  /// Quantity ordered.
  final int quantity;

  /// Price per unit.
  final Money unitPrice;

  /// Calculates the total price for this line item.
  Money get totalPrice => Money(
        amount: unitPrice.amount * quantity,
        currency: unitPrice.currency,
      );
}
