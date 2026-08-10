import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

/// Query handler for filtering users by first name
///
/// CUSTOM QUERY HANDLER PATTERN:
/// Query handlers allow you to implement custom filtering logic for collection
/// endpoints. They are registered with the CrudResource and invoked when a
/// matching query parameter is present in the request.
///
/// HOW QUERY HANDLERS WORK:
///
/// 1. REGISTRATION:
///    In main.dart, this handler is registered as:
///    queryHandlers: { 'firstName': firstNameQueryHandler }
///
/// 2. INVOCATION:
///    When a request comes in like: GET /users?firstName=John
///    The CrudResource detects the 'firstName' parameter and invokes this handler
///
/// 3. PARAMETERS:
///    - repository: The repository instance to query (`UserRepository`)
///    - queryParams: All query parameters from the request (e.g., {'firstName': 'John'})
///    - skip: Pagination offset (from ?skip=N or default)
///    - take: Pagination limit (from ?take=M or default)
///    - authResult: Optional authentication result if auth handler is configured
///
/// 4. RETURN VALUE:
///    Returns QueryResult<User> containing:
///    - items: The filtered and paginated list of users
///    - totalCount: Total number of matching users (before pagination)
///
/// 5. RESPONSE:
///    The CrudResource serializes the items to JSON array and includes
///    X-Total-Count header with the totalCount value
///
/// IMPLEMENTATION NOTES:
/// - This example uses case-insensitive matching for better UX
/// - The repository owns selection and pagination
/// - Empty/null parameter returns empty result (could also return 400 error)
Future<QueryResult<User>> userCollectionHandler(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) async {
  final page = await (repository as UserRepository).list(
    skip: skip,
    take: take,
  );
  return QueryResult(page.items, totalCount: page.totalCount);
}

Future<QueryResult<User>> firstNameQueryHandler(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) async {
  // Extract the firstName parameter from the query string
  final firstName = queryParams['firstName'];

  // Validate the parameter - return empty result if missing or empty
  // Alternative: throw an exception to return 400 Bad Request
  if (firstName == null || firstName.isEmpty) {
    return QueryResult<User>([], totalCount: 0);
  }

  final page = await (repository as UserRepository).findByFirstName(
    firstName,
    skip: skip,
    take: take,
  );

  // Return QueryResult with both the paginated items and total count
  // The total count is used for the X-Total-Count response header,
  // allowing clients to implement pagination UI (e.g., "Showing 1-10 of 25")
  return QueryResult<User>(
    page.items,
    totalCount: page.totalCount,
  );
}

/// Query handler for filtering users by email
///
/// EMAIL QUERY HANDLER:
/// This demonstrates a query handler for a unique field. Even though email
/// should be unique (at most one match), we still follow the same pattern:
/// - Return a list (not a single item)
/// - Apply pagination (even though it's usually unnecessary)
/// - Include totalCount (will be 0 or 1)
///
/// WHY RETURN A LIST FOR UNIQUE FIELDS?
/// - Consistency: All collection endpoints return arrays
/// - Flexibility: Email uniqueness is a business rule that might change
/// - REST convention: GET /users?email=x returns array, GET /users/:id returns object
/// - Client simplicity: Clients can use the same parsing logic for all queries
///
/// USAGE EXAMPLE:
/// GET /users?email=john.doe@example.com
/// Response: [{ "id": "...", "firstName": "John", ... }]
/// X-Total-Count: 1
///
/// If no match:
/// Response: []
/// X-Total-Count: 0
///
/// PRODUCTION CONSIDERATIONS:
/// - Add email format validation
/// - Consider case-sensitivity (emails are case-insensitive per RFC)
/// - For databases, use indexed queries for performance
/// - Consider rate limiting to prevent email enumeration attacks
Future<QueryResult<User>> emailQueryHandler(
  Repository<User> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) async {
  // Extract the email parameter from the query string
  final email = queryParams['email'];

  // Validate the parameter
  if (email == null || email.isEmpty) {
    return QueryResult<User>([], totalCount: 0);
  }

  final page = await (repository as UserRepository).findByEmail(
    email,
    skip: skip,
    take: take,
  );

  // Return QueryResult
  // For unique fields, totalCount will typically be 0 (not found) or 1 (found)
  return QueryResult<User>(
    page.items,
    totalCount: page.totalCount,
  );
}
