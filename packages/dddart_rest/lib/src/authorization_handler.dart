import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:dddart_rest/src/authorization_result.dart';

/// Base interface for authorization handlers
///
/// Implementations verify that authenticated users have permission
/// to perform operations on specific aggregates.
///
/// Generic over [TAggregate] (the resource type) and [TClaims]
/// (authentication claims type).
///
/// Authorization handlers are called after authentication succeeds
/// but before the operation is executed. They can access both the
/// aggregate being operated on and the authenticated user's claims
/// to make authorization decisions.
///
/// Example:
/// ```dart
/// class PlayerAuthorizationHandler
///     extends AuthorizationHandler<Player, StandardClaims> {
///   @override
///   Future<AuthorizationResult> authorizeUpdate(
///     Player player,
///     AuthenticationResult<StandardClaims> authResult,
///   ) async {
///     // Verify the player's cognitoSub matches the authenticated user
///     if (player.cognitoSub != authResult.claims?.sub) {
///       return AuthorizationResult.deny(
///         'You do not have permission to modify this player',
///       );
///     }
///     return AuthorizationResult.allow();
///   }
/// }
/// ```
abstract class AuthorizationHandler<TAggregate extends AggregateRoot, TClaims> {
  /// Authorizes a CREATE operation
  ///
  /// [aggregate] is the new aggregate being created
  /// [authResult] contains the authenticated user's identity and claims
  ///
  /// Returns [AuthorizationResult.allow] if authorized,
  /// or [AuthorizationResult.deny] with an error message if not authorized
  Future<AuthorizationResult> authorizeCreate(
    TAggregate aggregate,
    AuthenticationResult<TClaims> authResult,
  );

  /// Authorizes an UPDATE operation
  ///
  /// [aggregate] is the updated aggregate being saved
  /// [authResult] contains the authenticated user's identity and claims
  ///
  /// Returns [AuthorizationResult.allow] if authorized,
  /// or [AuthorizationResult.deny] with an error message if not authorized
  Future<AuthorizationResult> authorizeUpdate(
    TAggregate aggregate,
    AuthenticationResult<TClaims> authResult,
  );

  /// Authorizes a DELETE operation
  ///
  /// [aggregateId] is the ID of the aggregate being deleted
  /// [authResult] contains the authenticated user's identity and claims
  ///
  /// Note: The aggregate is not loaded yet, so implementations may need
  /// to fetch it from a repository if ownership checks are required.
  ///
  /// Returns [AuthorizationResult.allow] if authorized,
  /// or [AuthorizationResult.deny] with an error message if not authorized
  Future<AuthorizationResult> authorizeDelete(
    UuidValue aggregateId,
    AuthenticationResult<TClaims> authResult,
  );

  /// Authorizes a QUERY operation
  ///
  /// [queryParams] are the query parameters from the request
  /// [authResult] contains the authenticated user's identity and claims
  ///
  /// Note: This is called for filtered queries (e.g., ?cognitoSub=X).
  /// Unfiltered list queries typically don't require authorization.
  ///
  /// Returns [AuthorizationResult.allow] if authorized,
  /// or [AuthorizationResult.deny] with an error message if not authorized
  Future<AuthorizationResult> authorizeQuery(
    Map<String, String> queryParams,
    AuthenticationResult<TClaims> authResult,
  );
}
