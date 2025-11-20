import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'user.dart';
import 'user_repository.dart';

part 'user_with_custom_repo.g.dart';
part 'user_with_custom_repo_impl.dart';

/// User aggregate with custom repository interface.
///
/// This demonstrates how to use a custom repository interface that will
/// generate an abstract base class requiring custom method implementations.
@Serializable()
@GenerateMongoRepository(
  collectionName: 'users',
  implements: UserRepository,
)
class UserWithCustomRepo extends AggregateRoot {
  /// Creates a new User.
  UserWithCustomRepo({
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
