import 'package:dddart/dddart.dart';

/// Returns all items when repository exposes enumeration support.
///
/// This is capability-based and does not require concrete repository types.
List<T> requireQueryableItems<T extends AggregateRoot>(
  Repository<T> repository, {
  required String operationName,
}) {
  try {
    final dynamic dynamicRepository = repository;
    final result = dynamicRepository.getAll();
    if (result is List<T>) {
      return result;
    }
    if (result is List) {
      return result.cast<T>();
    }
  } catch (error) {
    if (error is! NoSuchMethodError) {
      rethrow;
    }
    // Fall through to unified unsupported error.
  }

  throw UnsupportedError(
    'Repository does not expose item enumeration for $operationName. '
    'Provide a repository implementation with getAll().',
  );
}

/// Finds the first matching item from a repository that supports enumeration.
T findFirstQueryableItem<T extends AggregateRoot>(
  Repository<T> repository,
  bool Function(T item) predicate, {
  required String operationName,
}) {
  final items = requireQueryableItems(
    repository,
    operationName: operationName,
  );
  return items.firstWhere(predicate);
}
