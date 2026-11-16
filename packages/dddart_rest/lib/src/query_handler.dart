import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authorization_context.dart';

/// Result from a query handler including items and optional total count
///
/// The QueryResult class encapsulates the results of a query operation,
/// including the list of matching items and an optional total count.
/// The total count is useful for pagination, allowing clients to know
/// the total number of items that match the query criteria.
class QueryResult<T extends AggregateRoot<Identity>> {
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

/// Application-owned collection selection after resource authorization.
///
/// Apply the authorized scope to both rows and totalCount BEFORE pagination.
/// Request filters may narrow that scope, never widen it. A handler may impose
/// additional restrictions by throwing AccessDeniedException. Public queries
/// receive an explicit UnrestrictedQueryScope rather than a fabricated identity.
typedef QueryHandler<T extends AggregateRoot<I>, I extends Identity, C>
    = Future<QueryResult<T>> Function(
  Repository<T, I> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  AuthorizedQuery<C> authorization,
);
