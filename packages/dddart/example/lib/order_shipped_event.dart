import 'package:dddart/dddart.dart';

/// Domain event raised when an order is shipped.
///
/// This event indicates that an order has left the warehouse and is
/// in transit to the customer. It can trigger notification emails,
/// tracking updates, and inventory adjustments.
class OrderShippedEvent extends DomainEvent {
  /// The tracking number for the shipment.
  final String trackingNumber;

  /// The shipping carrier (e.g., 'UPS', 'FedEx', 'USPS').
  final String carrier;

  /// The estimated delivery date.
  final DateTime estimatedDelivery;

  /// Creates a new OrderShippedEvent.
  ///
  /// [orderId] identifies the aggregate (order) that raised this event.
  /// [trackingNumber] is the shipment tracking identifier.
  /// [carrier] is the shipping company handling delivery.
  /// [estimatedDelivery] is when the package is expected to arrive.
  OrderShippedEvent({
    required UuidValue orderId,
    required this.trackingNumber,
    required this.carrier,
    required this.estimatedDelivery,
  }) : super(
          aggregateId: orderId,
          context: {
            'trackingNumber': trackingNumber,
            'carrier': carrier,
            'estimatedDelivery': estimatedDelivery.toIso8601String(),
          },
        );

  @override
  String toString() {
    return 'OrderShippedEvent(orderId: $aggregateId, tracking: $trackingNumber, carrier: $carrier)';
  }
}
