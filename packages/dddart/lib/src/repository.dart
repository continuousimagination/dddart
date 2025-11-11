import 'package:dddart/dddart.dart' show InMemoryRepository;
import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/in_memory_repository.dart' show InMemoryRepository;
import 'package:dddart/src/repository_exception.dart';
import 'package:dddart/src/uuid_value.dart';

/// Base interface for repositories that manage aggregate roots.
///
/// Repositories provide a collection-like interface for persisting and
/// retrieving aggregate roots, abstracting away data access details and
/// allowing domain logic to remain independent of persistence concerns.
///
/// The repository pattern encapsulates the logic required to access data
/// sources and provides a more object-oriented view of the persistence layer.
/// Repositories mediate between the domain and data mapping layers, acting
/// like an in-memory collection of aggregate roots.
///
/// ## Type Parameter
///
/// * [T] - The aggregate root type managed by this repository. Must extend
///   [AggregateRoot].
///
/// ## Usage Example
///
/// ```dart
/// // Define a custom repository interface for your aggregate
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> getByEmail(String email);
///   Future<List<User>> getActiveUsers();
/// }
///
/// // Implement the repository for a specific data store
/// class MySqlUserRepository implements UserRepository {
///   MySqlUserRepository(this.connection);
///
///   final MySqlConnection connection;
///
///   @override
///   Future<User> getById(UuidValue id) async {
///     final result = await connection.query(
///       'SELECT * FROM users WHERE id = ?',
///       [id.uuid],
///     );
///
///     if (result.isEmpty) {
///       throw RepositoryException(
///         'User with ID $id not found',
///         type: RepositoryExceptionType.notFound,
///       );
///     }
///
///     return User.fromRow(result.first);
///   }
///
///   @override
///   Future<void> save(User aggregate) async {
///     await connection.query(
///       '''
///       INSERT INTO users (id, name, email, created_at, updated_at)
///       VALUES (?, ?, ?, ?, ?)
///       ON DUPLICATE KEY UPDATE
///         name = VALUES(name),
///         email = VALUES(email),
///         updated_at = VALUES(updated_at)
///       ''',
///       [
///         aggregate.id.uuid,
///         aggregate.name,
///         aggregate.email,
///         aggregate.createdAt,
///         aggregate.updatedAt,
///       ],
///     );
///   }
///
///   @override
///   Future<void> deleteById(UuidValue id) async {
///     final result = await connection.query(
///       'DELETE FROM users WHERE id = ?',
///       [id.uuid],
///     );
///
///     if (result.affectedRows == 0) {
///       throw RepositoryException(
///         'User with ID $id not found',
///         type: RepositoryExceptionType.notFound,
///       );
///     }
///   }
///
///   @override
///   Future<User?> getByEmail(String email) async {
///     final result = await connection.query(
///       'SELECT * FROM users WHERE email = ?',
///       [email],
///     );
///
///     return result.isEmpty ? null : User.fromRow(result.first);
///   }
///
///   @override
///   Future<List<User>> getActiveUsers() async {
///     final result = await connection.query(
///       'SELECT * FROM users WHERE is_active = true',
///     );
///
///     return result.map((row) => User.fromRow(row)).toList();
///   }
/// }
///
/// // Use the repository in your application
/// final userRepository = MySqlUserRepository(connection);
///
/// // Save a new user
/// final user = User(name: 'John Doe', email: 'john@example.com');
/// await userRepository.save(user);
///
/// // Retrieve by ID
/// try {
///   final retrieved = await userRepository.getById(user.id);
///   print('Found user: ${retrieved.name}');
/// } on RepositoryException catch (e) {
///   if (e.type == RepositoryExceptionType.notFound) {
///     print('User not found');
///   }
/// }
///
/// // Delete by ID
/// await userRepository.deleteById(user.id);
/// ```
///
/// ## Error Handling
///
/// All repository methods may throw [RepositoryException] when operations fail.
/// Specific error scenarios:
///
/// * [getById] - Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
///   when no aggregate with the given ID exists.
/// * [deleteById] - Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
///   when no aggregate with the given ID exists.
/// * [save] - May throw [RepositoryException] with various types depending on the
///   failure reason (e.g., constraint violations, connection errors).
///
/// ## Extension Pattern
///
/// The base [Repository] interface provides only core CRUD operations. Extend it
/// to add domain-specific query methods:
///
/// ```dart
/// abstract interface class ProductRepository implements Repository<Product> {
///   Future<List<Product>> getByCategory(String category);
///   Future<List<Product>> searchByName(String searchTerm);
///   Future<List<Product>> getInPriceRange(double min, double max);
/// }
/// ```
///
/// ## Testing
///
/// For testing purposes, use [InMemoryRepository] which provides a simple
/// in-memory implementation:
///
/// ```dart
/// final repository = InMemoryRepository<User>();
///
/// // Use in tests without external dependencies
/// final user = User(name: 'Test User');
/// await repository.save(user);
/// final retrieved = await repository.getById(user.id);
/// expect(retrieved.name, equals('Test User'));
/// ```
///
/// See also:
/// * [AggregateRoot] - The base class for aggregate roots
/// * [InMemoryRepository] - An in-memory implementation for testing
/// * [RepositoryException] - Exception thrown by repository operations
abstract interface class Repository<T extends AggregateRoot> {
  /// Retrieves an aggregate root by its ID.
  ///
  /// Returns the aggregate root with the given [id].
  ///
  /// Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
  /// if no aggregate with the given ID exists. The rationale for throwing an
  /// exception rather than returning null is that if you have a UUID, you
  /// typically expect it to exist. UUIDs come from somewhere (user input,
  /// another system, etc.), and if you're looking it up, you expect to find it.
  ///
  /// May throw [RepositoryException] with other types if the operation fails
  /// for other reasons (e.g., connection errors, timeout).
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final user = await userRepository.getById(userId);
  ///   print('Found: ${user.name}');
  /// } on RepositoryException catch (e) {
  ///   if (e.type == RepositoryExceptionType.notFound) {
  ///     print('User does not exist');
  ///   } else {
  ///     print('Error retrieving user: ${e.message}');
  ///   }
  /// }
  /// ```
  Future<T> getById(UuidValue id);

  /// Saves an aggregate root to the repository.
  ///
  /// This operation performs an insert if the aggregate is new, or an update
  /// if it already exists (upsert semantics). The implementation determines
  /// whether to insert or update based on the aggregate's ID.
  ///
  /// The [aggregate] parameter is the aggregate root to save.
  ///
  /// Throws [RepositoryException] if the operation fails. The exception type
  /// will vary based on the failure reason:
  /// * [RepositoryExceptionType.duplicate] - A unique constraint was violated
  /// * [RepositoryExceptionType.constraint] - A database constraint was violated
  /// * [RepositoryExceptionType.connection] - A connection error occurred
  /// * [RepositoryExceptionType.timeout] - The operation timed out
  /// * [RepositoryExceptionType.unknown] - An unexpected error occurred
  ///
  /// Example:
  /// ```dart
  /// final user = User(name: 'Jane Doe', email: 'jane@example.com');
  ///
  /// try {
  ///   await userRepository.save(user);
  ///   print('User saved successfully');
  /// } on RepositoryException catch (e) {
  ///   if (e.type == RepositoryExceptionType.duplicate) {
  ///     print('A user with this email already exists');
  ///   } else {
  ///     print('Error saving user: ${e.message}');
  ///   }
  /// }
  /// ```
  Future<void> save(T aggregate);

  /// Deletes an aggregate root by its ID.
  ///
  /// Removes the aggregate with the given [id] from the repository.
  ///
  /// Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
  /// if no aggregate with the given ID exists. This ensures that delete
  /// operations are explicit and that attempting to delete a non-existent
  /// aggregate is treated as an error rather than a silent no-op.
  ///
  /// May throw [RepositoryException] with other types if the operation fails
  /// for other reasons (e.g., connection errors, constraint violations).
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await userRepository.deleteById(userId);
  ///   print('User deleted successfully');
  /// } on RepositoryException catch (e) {
  ///   if (e.type == RepositoryExceptionType.notFound) {
  ///     print('User does not exist');
  ///   } else if (e.type == RepositoryExceptionType.constraint) {
  ///     print('Cannot delete user: constraint violation');
  ///   } else {
  ///     print('Error deleting user: ${e.message}');
  ///   }
  /// }
  /// ```
  Future<void> deleteById(UuidValue id);
}
