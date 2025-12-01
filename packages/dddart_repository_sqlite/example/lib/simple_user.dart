/// Simple user aggregate for basic CRUD example.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'simple_user.g.dart';

/// A simple user aggregate with primitive fields.
@Serializable()
@GenerateSqliteRepository(tableName: 'users')
class SimpleUser extends AggregateRoot {
  /// Creates a simple user.
  SimpleUser({
    required this.name,
    required this.email,
    required this.age,
    required this.isActive,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's full name.
  final String name;

  /// User's email address.
  final String email;

  /// User's age.
  final int age;

  /// Whether the user account is active.
  final bool isActive;
}
