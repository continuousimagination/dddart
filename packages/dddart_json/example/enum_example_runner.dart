import 'package:dddart/dddart.dart';

import 'lib/domain/enum_example.dart';

void main() {
  // Create an order with enum status
  final order = Order(
    id: UuidValue.generate(),
    orderNumber: 'ORD-12345',
    status: OrderStatus.processing,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  print('Original order:');
  print('  Order Number: ${order.orderNumber}');
  print('  Status: ${order.status}');
  print('');

  // Serialize to JSON
  final serializer = OrderJsonSerializer();
  final jsonString = serializer.serialize(order);
  print('Serialized JSON:');
  print('  $jsonString');
  print('');

  // Deserialize from JSON
  final deserializedOrder = serializer.deserialize(jsonString);
  print('Deserialized order:');
  print('  Order Number: ${deserializedOrder.orderNumber}');
  print('  Status: ${deserializedOrder.status}');
  print('  Status is enum: ${deserializedOrder.status is OrderStatus}');
  print('');

  // Demonstrate all enum values
  print('All possible order statuses:');
  for (final status in OrderStatus.values) {
    print('  - ${status.name}');
  }
}
