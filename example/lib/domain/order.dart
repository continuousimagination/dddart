import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';
import 'address.dart';
import 'money.dart';
import 'order_item.dart';

part 'order.g.dart';

/// Order status as string constants
class OrderStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';
}

/// Aggregate root representing an order.
@Serializable()
class Order extends AggregateRoot {
  Order({
    required this.customerId,
    required this.items,
    required this.shippingAddress,
    required this.status,
    this.billingAddress,
    this.notes,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final UuidValue customerId;
  final List<OrderItem> items;
  final Address shippingAddress;
  final Address? billingAddress;
  final String status;
  final String? notes;



  /// Calculate the total amount for this order
  Money get total {
    if (items.isEmpty) return Money.zero('USD');
    
    final firstCurrency = items.first.unitPrice.currency;
    var totalAmount = 0.0;
    
    for (final item in items) {
      if (item.unitPrice.currency != firstCurrency) {
        throw StateError('All items must have the same currency');
      }
      totalAmount += item.totalPrice.amount;
    }
    
    return Money(amount: totalAmount, currency: firstCurrency);
  }

  /// Get the number of items in this order
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Check if this order can be cancelled
  bool get canBeCancelled => status == OrderStatus.pending || status == OrderStatus.confirmed;

  /// Check if this order can be shipped
  bool get canBeShipped => status == OrderStatus.confirmed;

  /// Check if this order is complete
  bool get isComplete => status == OrderStatus.delivered;

  /// Get the billing address, falling back to shipping if not set
  Address get effectiveBillingAddress => billingAddress ?? shippingAddress;

  @override
  String toString() => 'Order(${id.toString()}, ${items.length} items, $status)';

  /// Create a copy with updated status
  Order withStatus(String newStatus) {
    return Order(
      customerId: customerId,
      items: items,
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      status: newStatus,
      notes: notes,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy with additional notes
  Order withNotes(String? newNotes) {
    return Order(
      customerId: customerId,
      items: items,
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      status: status,
      notes: newNotes,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Add an item to the order
  Order addItem(OrderItem item) {
    return Order(
      customerId: customerId,
      items: [...items, item],
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      status: status,
      notes: notes,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove an item from the order by matching the item
  Order removeItem(OrderItem itemToRemove) {
    return Order(
      customerId: customerId,
      items: items.where((item) => item != itemToRemove).toList(),
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      status: status,
      notes: notes,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Validate the order
  bool get isValid {
    return items.isNotEmpty &&
           items.every((item) => item.isValid) &&
           total.isPositive;
  }
}