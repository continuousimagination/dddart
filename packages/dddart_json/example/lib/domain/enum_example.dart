import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'enum_example.g.dart';

/// Example enum for order status
enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
}

/// Example aggregate with enum field
@Serializable()
class Order extends AggregateRoot {
  Order({
    required this.orderNumber,
    required this.status,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String orderNumber;
  final OrderStatus status;
}
