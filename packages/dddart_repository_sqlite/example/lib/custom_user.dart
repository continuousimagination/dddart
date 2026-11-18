/// User aggregate with custom repository interface.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'custom_user.g.dart';
part 'custom_user_repository_impl.dart';

/// User aggregate with email and active status.
@Serializable()
@GenerateSqliteRepository(
  tableName: 'custom_users',
  implements: CustomUserRepository,
)
class CustomUser extends AggregateRoot<UuidValue> {
  /// Creates a custom user.
  CustomUser({
    required this.name,
    required this.email,
    required this.isActive,
    required this.registeredAt,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  }) : super(id: id ?? UuidValue.generate());

  /// User's full name.
  final String name;

  /// User's email address.
  final String email;

  /// Whether the user account is active.
  final bool isActive;

  /// When the user registered.
  final DateTime registeredAt;
}

/// Custom repository interface with domain-specific query methods.
abstract interface class CustomUserRepository
    implements Repository<CustomUser, UuidValue> {
  /// Finds the first active users in name order.
  Future<List<CustomUser>> findActiveUsers({int limit = 20});
}
