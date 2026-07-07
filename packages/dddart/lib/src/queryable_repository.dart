import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/repository.dart';

/// A repository that supports enumerating all stored items.
///
/// Extends [Repository] with the ability to retrieve all aggregates,
/// enabling collection-level queries like filtering, sorting, and
/// pagination over the full dataset.
///
/// Not all repository implementations support this — for example,
/// a repository backed by a large external database might not want
/// to load all records into memory. Implementations that DO support
/// full enumeration (in-memory, small DynamoDB tables via Scan) should
/// implement this interface.
///
/// ## Usage
///
/// The `dddart_rest` `CrudResource` uses this interface for collection
/// queries (GET all items) and query handlers. If a repository does not
/// implement `QueryableRepository`, collection-level endpoints will
/// return an appropriate error.
///
/// ```dart
/// // In-memory repositories implement this automatically:
/// final repo = InMemoryRepository<User>();
/// final allUsers = repo.getAll();
///
/// // DynamoDB repositories also implement it (via table scan):
/// final dynamoRepo = UserDynamoRepository(connection);
/// final allUsers = await dynamoRepo.getAll();
/// ```
///
/// See also:
/// * [Repository] — the base CRUD interface
/// * [InMemoryRepository] — an implementation that supports getAll()
abstract interface class QueryableRepository<T extends AggregateRoot>
    implements Repository<T> {
  /// Returns all aggregates currently in the repository.
  ///
  /// For in-memory repositories, this returns the contents of the
  /// internal map. For database-backed repositories, this performs a
  /// full table scan.
  ///
  /// **Performance note:** For large datasets, prefer dedicated query
  /// methods with filtering and pagination over `getAll()`.
  Future<List<T>> getAll();
}
