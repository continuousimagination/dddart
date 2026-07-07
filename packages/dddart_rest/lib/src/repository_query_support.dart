import 'package:dddart/dddart.dart';

/// Returns all items from a repository that implements [QueryableRepository].
///
/// Throws [UnsupportedError] if the repository does not implement
/// [QueryableRepository] — meaning it cannot enumerate all items.
Future<List<T>> getAllItems<T extends AggregateRoot>(
  Repository<T> repository, {
  required String operationName,
}) async {
  if (repository is QueryableRepository<T>) {
    return repository.getAll();
  }

  throw UnsupportedError(
    'Repository does not implement QueryableRepository<$T>. '
    'The "$operationName" operation requires a repository that supports '
    'item enumeration via getAll(). '
    'Use InMemoryRepository or a DynamoDB repository (which supports Scan) '
    'instead of a plain Repository<$T>.',
  );
}

/// Finds the first item matching [predicate] from a queryable repository.
///
/// Throws [UnsupportedError] if the repository doesn't implement
/// [QueryableRepository]. Throws [StateError] if no matching item is found.
Future<T> findFirstItem<T extends AggregateRoot>(
  Repository<T> repository,
  bool Function(T item) predicate, {
  required String operationName,
}) async {
  final items = await getAllItems(
    repository,
    operationName: operationName,
  );
  return items.firstWhere(predicate);
}

/// Legacy aliases for backward compatibility during migration.
/// TODO(cleanup): Remove these after all consumers are updated.

/// @deprecated Use [getAllItems] instead.
Future<List<T>> requireQueryableItems<T extends AggregateRoot>(
  Repository<T> repository, {
  required String operationName,
}) =>
    getAllItems(repository, operationName: operationName);

/// @deprecated Use [findFirstItem] instead.
Future<T> findFirstQueryableItem<T extends AggregateRoot>(
  Repository<T> repository,
  bool Function(T item) predicate, {
  required String operationName,
}) =>
    findFirstItem(repository, predicate, operationName: operationName);
