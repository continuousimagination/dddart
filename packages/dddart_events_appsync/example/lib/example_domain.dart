import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

/// Shared example wire contract; production apps register their own event types.
class ExampleChanged extends DomainEvent<UuidValue> {
  ExampleChanged(
      {required super.aggregateId,
      required this.message,
      super.eventId,
      super.occurredAt,
      super.context});
  final String message;
  Map<String, dynamic> toJson() => {
        'aggregateId': aggregateId.uuid,
        'eventId': eventId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'context': context,
        'message': message
      };
  static ExampleChanged fromJson(Map<String, dynamic> json) => ExampleChanged(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      eventId: UuidValue.fromString(json['eventId'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      context: Map<String, dynamic>.from(json['context'] as Map),
      message: json['message'] as String);
}

EventRegistry exampleRegistry() => EventRegistry()
  ..register<ExampleChanged>('example.changed.v1',
      encode: (event) => event.toJson(), decode: ExampleChanged.fromJson);
