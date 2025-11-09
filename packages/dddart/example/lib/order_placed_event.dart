import 'package:dddart/dddart.dart';

/// Domain event raised when an order is successfully placed.
///
/// This event signals that an order has been created and is ready for processing.
/// It can trigger inventory updates, payment processing, and shipping workflows.
class OrderPlacedEvent extends DomainEvent {
  /// The customer who placed the order.
  final String customerId;

  /// The total amount of the order.
  final double totalAmount;

  /// The currency of the order amount.
  final String currency;

  /// Number of items in the order.
  final int itemCount;

  /// Creates a new OrderPlacedEvent.
  ///
  /// [orderId] identifies the aggregate (order) that raised this event.
  /// [customerId] identifies the customer who placed the order.
  /// [totalAmount] is the total order value.
  /// [currency] is the currency code (e.g., 'USD').
  /// [itemCount] is the number of items in the order.
  OrderPlacedEvent({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
  }) : super(
          aggregateId: orderId,
          context: {
            'customerId': customerId,
            'totalAmount': totalAmount,
            'currency': currency,
            'itemCount': itemCount,
          },
        );

  @override
  String toString() {
    return 'OrderPlacedEvent(orderId: $aggregateId, customer: $customerId, total: $totalAmount $currency)';
  }
}
