/// User aggregate with custom repository interface.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user_with_custom_repo.g.dart';
part 'user_with_custom_repo_impl.dart';

/// Custom repository interface with domain-specific query methods.
abstract interface class UserRepository
    implements Repository<UserWithCustomRepo> {
  /// Finds at most one user through the email global secondary index.
  Future<UserWithCustomRepo?> findByEmail(String email);

  /// Finds at most [limit] users with [lastName], ordered by email address.
  Future<List<UserWithCustomRepo>> findByLastName(
    String lastName, {
    required int limit,
  });
}

/// User aggregate demonstrating custom repository interface.
@Serializable()
@GenerateDynamoRepository(
  tableName: 'users_with_custom_repo',
  implements: UserRepository,
)
class UserWithCustomRepo extends AggregateRoot {
  /// Creates a user.
  UserWithCustomRepo({
    required this.firstName,
    required this.lastName,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's first name.
  final String firstName;

  /// User's last name.
  final String lastName;

  /// User's email address.
  final String email;

  /// Returns the user's full name.
  String get fullName => '$firstName $lastName';
}
