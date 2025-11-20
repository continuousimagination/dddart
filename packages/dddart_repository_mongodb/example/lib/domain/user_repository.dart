import 'package:dddart/dddart.dart';
import 'user_with_custom_repo.dart';

/// Custom repository interface for UserWithCustomRepo aggregate with domain-specific queries.
///
/// This interface extends the base Repository<UserWithCustomRepo> with custom query methods.
/// The MongoDB implementation will be generated as an abstract base class,
/// requiring the developer to implement the custom methods.
abstract interface class UserRepository
    implements Repository<UserWithCustomRepo> {
  /// Finds a user by their email address.
  ///
  /// Returns null if no user with the given email exists.
  Future<UserWithCustomRepo?> findByEmail(String email);

  /// Finds all users with the given last name.
  Future<List<UserWithCustomRepo>> findByLastName(String lastName);
}
