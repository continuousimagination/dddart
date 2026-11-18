import 'package:dddart/dddart.dart' show InMemoryRepository;
import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/in_memory_repository.dart' show InMemoryRepository;
import 'package:dddart/src/repository_exception.dart';

/// Loads, saves and deletes [AggregateRoot] objects of type [T] by identity [I].
///
/// Define a separate interface for domain-specific queries. An application
/// service that only needs CRUD can take a [Repository] and use the same
/// code with an [InMemoryRepository] or a persistent adapter.
///
/// Missing IDs on lookup or deletion throw [RepositoryException] with type
/// [RepositoryExceptionType.notFound].
abstract interface class Repository<T extends AggregateRoot<I>,
    I extends Identity> {
  /// Retrieves an aggregate root by its ID.
  ///
  /// Returns the aggregate root with the given [id].
  ///
  /// Throws [RepositoryException] with type [RepositoryExceptionType.notFound]
  /// if no aggregate with the given ID exists. Lookup returns an aggregate or
  /// throws; an externally assigned identity does not change this contract.
  ///
  /// May throw [RepositoryException] with other types if the operation fails
  /// for other reasons (e.g., connection errors, timeout).
  Future<T> getById(I id);

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
  Future<void> deleteById(I id);
}
