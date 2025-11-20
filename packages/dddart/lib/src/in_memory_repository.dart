import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/repository.dart';
import 'package:dddart/src/repository_exception.dart';
import 'package:dddart/src/uuid_value.dart';
import 'package:logging/logging.dart';

/// In-memory implementation of [Repository] for testing purposes.
///
/// Stores aggregate roots in a Map keyed by their ID. This implementation
/// is useful for unit tests and prototyping, but should not be used in
/// production as data is not persisted and will be lost when the application
/// terminates.
///
/// The [InMemoryRepository] provides a simple, fast implementation that
/// requires no external dependencies or setup, making it ideal for:
/// * Unit testing domain logic
/// * Integration testing without database setup
/// * Rapid prototyping and development
/// * Learning and experimentation
///
/// ## Type Parameter
///
/// * [T] - The aggregate root type managed by this repository. Must extend
///   [AggregateRoot].
///
/// ## Usage Example
///
/// ```dart
/// // Create a repository for User aggregates
/// final userRepository = InMemoryRepository<User>();
///
/// // Save a user
/// final user = User(name: 'John Doe', email: 'john@example.com');
/// await userRepository.save(user);
///
/// // Retrieve the user
/// final retrieved = await userRepository.getById(user.id);
/// print('Found: ${retrieved.name}');
///
/// // Update the user
/// retrieved.updateEmail('newemail@example.com');
/// await userRepository.save(retrieved);
///
/// // Delete the user
/// await userRepository.deleteById(user.id);
///
/// // Clean up for next test
/// userRepository.clear();
/// ```
///
/// ## Testing Utilities
///
/// The [InMemoryRepository] includes additional utility methods for testing:
///
/// ```dart
/// test('repository operations', () async {
///   final repository = InMemoryRepository<User>();
///
///   // Add test data
///   final user1 = User(name: 'Alice');
///   final user2 = User(name: 'Bob');
///   await repository.save(user1);
///   await repository.save(user2);
///
///   // Verify all users are stored
///   final allUsers = repository.getAll();
///   expect(allUsers, hasLength(2));
///
///   // Clean up after test
///   repository.clear();
///   expect(repository.getAll(), isEmpty);
/// });
/// ```
///
/// ## Thread Safety
///
/// This implementation is not thread-safe. If you need concurrent access,
/// consider using appropriate synchronization mechanisms or a different
/// repository implementation designed for concurrent use.
///
/// ## Storage Isolation
///
/// Each instance of [InMemoryRepository] maintains its own independent storage.
/// Different instances do not share data, even for the same aggregate type:
///
/// ```dart
/// final repo1 = InMemoryRepository<User>();
/// final repo2 = InMemoryRepository<User>();
///
/// final user = User(name: 'Alice');
/// await repo1.save(user);
///
/// // repo2 does not have access to user
/// expect(() => repo2.getById(user.id), throwsA(isA<RepositoryException>()));
/// ```
///
/// See also:
/// * [Repository] - The base repository interface
/// * [AggregateRoot] - The base class for aggregate roots
/// * [RepositoryException] - Exception thrown by repository operations
class InMemoryRepository<T extends AggregateRoot> implements Repository<T> {
  /// Logger instance for repository operations.
  final Logger _logger = Logger('dddart.repository');

  /// Internal storage map that holds aggregates keyed by their ID.
  final Map<UuidValue, T> _storage = {};

  @override
  Future<T> getById(UuidValue id) async {
    try {
      _logger.fine('Retrieving $T with ID: $id');
      final aggregate = _storage[id];
      if (aggregate == null) {
        throw RepositoryException(
          'Aggregate with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      return aggregate;
    } catch (e, stackTrace) {
      _logger.severe('Failed to retrieve $T with ID: $id', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> save(T aggregate) async {
    try {
      _logger.fine('Saving $T with ID: ${aggregate.id}');
      _storage[aggregate.id] = aggregate;
    } catch (e, stackTrace) {
      _logger.severe(
        'Failed to save $T with ID: ${aggregate.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      _logger.fine('Deleting $T with ID: $id');
      if (!_storage.containsKey(id)) {
        throw RepositoryException(
          'Aggregate with ID $id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      _storage.remove(id);
    } catch (e, stackTrace) {
      _logger.severe('Failed to delete $T with ID: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Clears all aggregates from the repository.
  ///
  /// This method removes all stored aggregates, resetting the repository
  /// to an empty state. It is particularly useful for test cleanup to
  /// ensure tests start with a clean slate.
  ///
  /// Example:
  /// ```dart
  /// test('user operations', () async {
  ///   final repository = InMemoryRepository<User>();
  ///
  ///   // Perform test operations
  ///   await repository.save(User(name: 'Test User'));
  ///
  ///   // Clean up
  ///   repository.clear();
  ///   expect(repository.getAll(), isEmpty);
  /// });
  /// ```
  void clear() {
    _storage.clear();
  }

  /// Returns all aggregates in the repository.
  ///
  /// Returns an unmodifiable list containing all aggregate roots currently
  /// stored in the repository. The order of aggregates in the list is not
  /// guaranteed.
  ///
  /// This method is useful for:
  /// * Testing and verification
  /// * Debugging and inspection
  /// * Bulk operations in test scenarios
  ///
  /// Note: The returned list is unmodifiable. Attempting to modify it will
  /// throw an [UnsupportedError].
  ///
  /// Example:
  /// ```dart
  /// final repository = InMemoryRepository<User>();
  /// await repository.save(User(name: 'Alice'));
  /// await repository.save(User(name: 'Bob'));
  ///
  /// final allUsers = repository.getAll();
  /// print('Total users: ${allUsers.length}');
  /// for (final user in allUsers) {
  ///   print('User: ${user.name}');
  /// }
  /// ```
  List<T> getAll() {
    return List.unmodifiable(_storage.values);
  }
}
