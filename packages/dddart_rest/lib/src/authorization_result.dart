import 'package:dddart_rest/src/authorization_context.dart';

/// An application access decision, optionally carrying a query scope.
class AuthorizationResult {
  const AuthorizationResult._(this.isAuthorized, this.scope, this.conceal);

  /// Allows the operation. Collection decisions must explicitly supply [scope].
  const AuthorizationResult.allow({QueryScope? scope})
      : this._(true, scope, false);

  /// Denies access with 403, or a generic 404 to conceal resource existence.
  const AuthorizationResult.deny({bool conceal = false})
      : this._(false, null, conceal);

  /// Whether execution may proceed.
  final bool isAuthorized;

  /// Application-owned row/count scope for an allowed collection read.
  final QueryScope? scope;

  /// Whether a denial should conceal existence.
  final bool conceal;
}
