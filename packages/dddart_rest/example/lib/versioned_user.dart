import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'versioned_user.g.dart';

/// Example aggregate with one inherited atomic concurrency revision.
@Serializable()
class VersionedUser extends VersionedAggregateRoot {
  /// Creates a complete proposal or reconstructs a persisted snapshot.
  VersionedUser({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    super.revision = const Revision.zero(),
  });

  /// Synthetic display name used by the concurrency example.
  final String name;
}
