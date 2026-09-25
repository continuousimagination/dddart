/// Input library for the actual standalone event registry build.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Synthetic event with a public typed factory.
@Serializable()
class RegistryFixtureEvent extends DomainEvent {
  /// Creates a test event.
  RegistryFixtureEvent({required super.aggregateId, required this.message});

  /// Synthetic event data.
  final String message;

  /// Decodes the event through the registry's public factory signature.
  static RegistryFixtureEvent fromJson(Map<String, dynamic> json) =>
      RegistryFixtureEvent(
        aggregateId: UuidValue.fromString(json['aggregateId'] as String),
        message: json['message'] as String,
      );
}
