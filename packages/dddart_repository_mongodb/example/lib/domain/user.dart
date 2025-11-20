import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';

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
    UuidValue? id,
  }) : super(id: id);

  /// User's first name.
  final String firstName;

  /// User's last name.
  final String lastName;

  /// User's email address.
  final String email;

  /// Gets the user's full name.
  String get fullName => '$firstName $lastName';
}
