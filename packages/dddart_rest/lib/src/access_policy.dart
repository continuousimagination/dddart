import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authorization_handler.dart';

/// Whether an operation can evaluate access for an anonymous caller.
enum AuthenticationRequirement {
  /// Missing credentials are anonymous; supplied credentials must verify.
  optional,

  /// The configured verifier must authenticate this request.
  required,
}

/// One reviewable operation policy; an override replaces the resource default.
final class AccessPolicy<T extends AggregateRoot<I>, I extends Identity, C> {
  /// Allows anonymous access without an application authorization hook.
  const AccessPolicy.public()
      : authentication = AuthenticationRequirement.optional,
        handler = null;

  /// Requires verified identity without imposing domain-specific permissions.
  const AccessPolicy.authenticated()
      : authentication = AuthenticationRequirement.required,
        handler = null;

  /// Always evaluates [handler], including anonymous callers when optional.
  const AccessPolicy.custom(
    AuthorizationHandler<T, I, C> this.handler, {
    this.authentication = AuthenticationRequirement.optional,
  });

  /// Missing versus required credential behavior for this operation.
  final AuthenticationRequirement authentication;

  /// Application policy, or null for public/authentication-only access.
  final AuthorizationHandler<T, I, C>? handler;
}

/// A deliberate access rejection, including optional existence concealment.
class AccessDeniedException implements Exception {
  /// Returns 403, or a generic 404 when existence should be concealed.
  const AccessDeniedException({this.conceal = false});

  /// Whether to conceal existence with the same response as a missing record.
  final bool conceal;
}

/// A policy/verifier failed unexpectedly; no operation may continue.
class AccessEvaluationException implements Exception {
  /// Does not retain sensitive handler exception text in an HTTP response.
  const AccessEvaluationException();
}
