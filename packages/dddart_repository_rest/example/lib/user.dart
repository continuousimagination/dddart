/// Example domain model for a User aggregate.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user.g.dart';

/// User aggregate root representing a user in the system.
@Serializable()
@GenerateRestRepository(resourcePath: '/users')
class User extends AggregateRoot {
  /// Creates a new user.
  User({
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

  /// Gets the user's full name.
  String get fullName => '$firstName $lastName';
}
