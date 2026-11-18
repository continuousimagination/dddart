import 'dart:convert';

import 'package:dddart/dddart.dart';

/// A handwritten event format for a system that receives JSON text.
class OrderPlaced extends DomainEvent<UuidValue, UuidValue> {
  OrderPlaced({
    required super.aggregateId,
    required this.itemCount,
    UuidValue? eventId,
    super.occurredAt,
    super.context,
  }) : super(eventId: eventId ?? UuidValue.generate());

  final int itemCount;

  Map<String, dynamic> toJson() => {
        'aggregateId': aggregateId.uuid,
        'eventId': eventId.uuid,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'itemCount': itemCount,
        'context': context,
      };

  factory OrderPlaced.fromJson(Map<String, dynamic> json) => OrderPlaced(
        aggregateId: UuidValue.fromString(json['aggregateId'] as String),
        eventId: UuidValue.fromString(json['eventId'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        itemCount: json['itemCount'] as int,
        context: json['context'] as Map<String, dynamic>,
      );
}

void main() {
  final placed = OrderPlaced(
    aggregateId: UuidValue.generate(),
    itemCount: 2,
    context: {'channel': 'store'},
  );

  final message = jsonEncode(placed.toJson());
  final received =
      OrderPlaced.fromJson(jsonDecode(message) as Map<String, dynamic>);

  if (received.eventId != placed.eventId ||
      received.aggregateId != placed.aggregateId ||
      !received.occurredAt.isAtSameMomentAs(placed.occurredAt) ||
      received.itemCount != placed.itemCount ||
      received.context['channel'] != placed.context['channel']) {
    throw StateError('The event changed during the JSON round trip.');
  }
  print('Received the original order event with ${received.itemCount} items.');
}
