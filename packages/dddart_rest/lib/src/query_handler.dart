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
/// Query handlers process collection reads and return explicitly selected
/// results. Named handlers are invoked when a GET request includes the
/// corresponding query parameter. A `CrudResource` can also register one as its
/// unfiltered collection handler; that handler receives an empty parameter map.
///
/// Parameters:
/// - [repository]: The repository instance to query
/// - [queryParams]: Filter parameters from the request (excluding skip/take), or
///   an empty map for an unfiltered collection request
/// - [skip]: Number of items to skip (for pagination)
/// - [take]: Number of items to return (for pagination)
/// - [authResult]: Optional authentication result if auth handler is configured
///
/// Returns: QueryResult containing the filtered items and optional total count
///
/// Example:
/// ```dart
/// abstract interface class UserRepository implements Repository<User> {
///   Future<({List<User> items, int totalCount})> findByFirstName(
///     String firstName, {
///     required int skip,
///     required int take,
///   });
/// }
///
/// final firstNameHandler = (Repository<User> repository,
///                           Map<String, String> queryParams,
///                           int skip,
///                           int take,
///                           dynamic authResult) async {
///   final firstName = queryParams['firstName']!;
///   final page = await (repository as UserRepository).findByFirstName(
///     firstName,
///     skip: skip,
///     take: take,
///   );
///   return QueryResult(
///     page.items,
///     totalCount: page.totalCount,
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
