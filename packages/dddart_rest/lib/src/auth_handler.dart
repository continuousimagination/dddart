import 'package:dddart_rest/src/auth_result.dart';
import 'package:shelf/shelf.dart';

/// Base class for authentication handlers
///
/// Implementations validate credentials from HTTP requests and return
/// authentication results containing user identity and claims.
///
/// Generic over [TClaims] to support strongly-typed custom claims.
// ignore: one_member_abstracts
abstract class AuthHandler<TClaims> {
  /// Authenticates a request and returns authentication result
  ///
  /// Extracts credentials from the request (typically Authorization header),
  /// validates them, and returns user identity and claims.
  ///
  /// Returns [AuthResult] with isAuthenticated true if validation succeeds,
  /// or false with an error message if validation fails.
  Future<AuthResult<TClaims>> authenticate(Request request);
}
