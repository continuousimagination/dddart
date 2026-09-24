/// Independent JSON example for a StoredEvent subtype.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'custom_stored_event.g.dart';

/// Stored event with application-specific authorization fields.
///
/// This type demonstrates only the existing JSON serializer behavior. It does
/// not define event-registry, HTTP transport, polling, or bulk-range semantics.
@Serializable()
class CustomStoredEvent extends StoredEvent {
  /// Creates a stored event with optional authorization metadata.
  CustomStoredEvent({
    required super.id,
    required super.createdAt,
    required super.aggregateId,
    required super.eventType,
    required super.eventJson,
    super.updatedAt,
    super.userId,
    super.tenantId,
    super.sessionId,
    this.userRoles,
    this.organizationId,
  });

  /// User roles for role-based authorization.
  final List<String>? userRoles;

  /// Organization identifier for organization-specific filtering.
  final String? organizationId;
}
