import 'package:dddart/dddart.dart' show InMemoryRepository;
import 'package:dddart/src/aggregate_root.dart';
import 'package:dddart/src/identity.dart';
import 'package:dddart/src/in_memory_repository.dart' show InMemoryRepository;
import 'package:dddart/src/repository_exception.dart';

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
/// * [I] - The concrete identity of [T], accepted by lookup and deletion.
///
/// ## Usage Example
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
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
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
///
/// ## Testing
///
/// For testing purposes, use [InMemoryRepository] which provides a simple
/// in-memory implementation:
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
///
/// See also:
/// * [AggregateRoot] - The base class for aggregate roots
/// * [InMemoryRepository] - An in-memory implementation for testing
/// * [RepositoryException] - Exception thrown by repository operations
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
  ///
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
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
  ///
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
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
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart/README.md).
  Future<void> deleteById(I id);
}
