import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';
import 'money.dart';
import 'product_info.dart';

part 'order_item.g.dart';

/// Value object representing an item within an order.
/// 
/// Changed from Entity to Value to make the example work.
/// In a real system, you might keep this as an Entity and handle
/// the serialization inline within the Order aggregate.
@Serializable()
class OrderItem extends Value {
  const OrderItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final ProductInfo product;
  final int quantity;
  final Money unitPrice;

  @override
  List<Object?> get props => [product, quantity, unitPrice];

  /// Calculate the total price for this line item
  Money get totalPrice => unitPrice * quantity.toDouble();

  /// Check if this is a valid order item
  bool get isValid => quantity > 0 && unitPrice.isPositive;

  /// Get a description of this order item
  String get description => '${product.name} x $quantity @ ${unitPrice.toString()}';

  @override
  String toString() => 'OrderItem(${product.sku}, qty: $quantity, price: $unitPrice)';

  /// Create a copy with updated quantity
  OrderItem withQuantity(int newQuantity) {
    return OrderItem(
      product: product,
      quantity: newQuantity,
      unitPrice: unitPrice,
    );
  }

  /// Create a copy with updated price
  OrderItem withPrice(Money newPrice) {
    return OrderItem(
      product: product,
      quantity: quantity,
      unitPrice: newPrice,
    );
  }
}