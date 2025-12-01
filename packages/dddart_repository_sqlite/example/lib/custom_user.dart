/// User aggregate with custom repository interface.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'custom_user.g.dart';

/// User aggregate with email and active status.
@Serializable()
@GenerateSqliteRepository(
  tableName: 'custom_users',
  implements: CustomUserRepository,
)
class CustomUser extends AggregateRoot {
  /// Creates a custom user.
  CustomUser({
    required this.name,
    required this.email,
    required this.isActive,
    required this.registeredAt,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

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
    implements Repository<CustomUser> {
  /// Finds all active users.
  Future<List<CustomUser>> findActiveUsers();

  /// Finds users by email pattern.
  Future<List<CustomUser>> findByEmailPattern(String pattern);

  /// Counts total users.
  Future<int> countUsers();

  /// Finds users registered after a specific date.
  Future<List<CustomUser>> findRegisteredAfter(DateTime date);
}
