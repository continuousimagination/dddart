/// Annotation for generating REST API-backed repository implementations.
///
/// This annotation marks aggregate root classes for code generation of
/// repository implementations that communicate with REST APIs via HTTP.
///
/// ## Basic Usage
///
/// ```dart
/// @Serializable()
/// @GenerateRestRepository(resourcePath: '/users')
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///
///   User({required this.firstName, required this.lastName});
/// }
/// ```
///
/// ## Resource Path
///
/// The [resourcePath] parameter specifies the URL path segment for the
/// aggregate type. If omitted, the path is generated from the class name
/// by converting to lowercase and pluralizing (e.g., User → users,
/// OrderItem → order-items).
///
/// ## Custom Interfaces
///
/// The [implements] parameter allows you to specify a custom repository
/// interface with domain-specific query methods. When provided, the
/// generator creates an abstract base class that you must extend:
///
/// ```dart
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> findByEmail(String email);
/// }
///
/// @Serializable()
/// @GenerateRestRepository(implements: UserRepository)
/// class User extends AggregateRoot {
///   final String email;
///   User({required this.email});
/// }
///
/// class UserRestRepository extends UserRestRepositoryBase {
///   UserRestRepository(super.connection);
///
///   @override
///   Future<User?> findByEmail(String email) async {
///     // Custom implementation using _connection, _serializer, etc.
///   }
/// }
/// ```
class GenerateRestRepository {
  /// Creates a REST repository generation annotation.
  ///
  /// [resourcePath] - Optional REST API resource path (e.g., '/users').
  /// If null, generates from class name (User → 'users').
  ///
  /// [implements] - Optional custom repository interface to implement.
  /// If provided with custom methods, generates abstract base class.
  /// If null or only has base methods, generates concrete class.
  const GenerateRestRepository({
    this.resourcePath,
    this.implements,
  });

  /// The REST API resource path (e.g., '/users', '/orders').
  ///
  /// If null, the path is generated from the class name by converting
  /// to lowercase and pluralizing. For example:
  /// - User → 'users'
  /// - OrderItem → 'order-items'
  final String? resourcePath;

  /// Optional custom repository interface to implement.
  ///
  /// If provided with methods beyond base Repository<T>, generates an
  /// abstract base class requiring custom method implementation.
  ///
  /// If null or only has base methods, generates a concrete repository
  /// class ready for direct use.
  final Type? implements;
}
