import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
// The generated repository part uses mongo_dart's public database types.
// ignore: unused_import
import 'package:mongo_dart/mongo_dart.dart';

part 'user.g.dart';

/// Example User aggregate demonstrating basic MongoDB repository usage.
@Serializable()
@GenerateMongoRepository(collectionName: 'users')
class User extends AggregateRoot {
  /// Creates a new User.
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
