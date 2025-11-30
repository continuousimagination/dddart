import 'package:dddart/dddart.dart';

/// Result from a query handler including items and optional total count
///
/// The QueryResult class encapsulates the results of a query operation,
/// including the list of matching items and an optional total count.
/// The total count is useful for pagination, allowing clients to know
/// the total number of items that match the query criteria.
class QueryResult<T extends AggregateRoot> {
  /// Creates a QueryResult with the given items and optional total count
  ///
  /// Parameters:
  /// - [items]: The list of aggregate roots that match the query
  /// - [totalCount]: Optional total count of all matching items (useful for pagination)
  QueryResult(this.items, {this.totalCount});

  /// The list of aggregate roots that match the query
  final List<T> items;

  /// Optional total count of all matching items
  ///
  /// When provided, this indicates the total number of items that match
  /// the query criteria, regardless of pagination. This is useful for
  /// clients to display pagination information (e.g., "Showing 10 of 150").
  final int? totalCount;
}

/// Function signature for query handlers
///
/// Query handlers process query parameters and return filtered results.
/// They are registered with a CrudResource and invoked when a GET request
/// to a collection endpoint includes the corresponding query parameter.
///
/// Parameters:
/// - [repository]: The repository instance to query
/// - [queryParams]: All query parameters from the request (excluding skip/take)
/// - [skip]: Number of items to skip (for pagination)
/// - [take]: Number of items to return (for pagination)
/// - [authResult]: Optional authentication result if auth handler is configured
///
/// Returns: QueryResult containing the filtered items and optional total count
///
/// Example:
/// ```dart
/// final firstNameHandler = (Repository<User> repository,
///                           Map<String, String> queryParams,
///                           int skip,
///                           int take,
///                           AuthResult? authResult) async {
///   final firstName = queryParams['firstName']!;
///   final allMatches = await repository.getByFirstName(firstName);
///   return QueryResult(
///     allMatches.skip(skip).take(take).toList(),
///     totalCount: allMatches.length,
///   );
/// };
/// ```
typedef QueryHandler<T extends AggregateRoot> = Future<QueryResult<T>> Function(
  Repository<T> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
);
