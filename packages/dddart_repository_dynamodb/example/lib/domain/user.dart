/// Simple user aggregate for basic CRUD examples.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'user.g.dart';

/// User aggregate demonstrating basic DynamoDB repository usage.
@Serializable()
@GenerateDynamoRepository(tableName: 'users')
class User extends AggregateRoot {
  /// Creates a user.
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

  /// Returns the user's full name.
  String get fullName => '$firstName $lastName';
}
