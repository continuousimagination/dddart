import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authentication_result.dart';

/// Independently configurable resource operations.
enum CrudOperation {
  /// Read one persisted aggregate.
  read,

  /// Read a filtered or unfiltered collection.
  query,

  /// Create a new aggregate.
  create,

  /// Replace an existing aggregate.
  update,

  /// Remove an existing aggregate.
  delete,
}

/// A caller whose identity has either been verified or is explicitly anonymous.
sealed class Caller<C> {
  const Caller();

  /// Whether credential verification succeeded.
  bool get isAuthenticated;

  /// Verified application claims, if supplied by the authenticator.
  C? get claims;

  /// Verified subject identifier, if supplied by the authenticator.
  String? get userId;
}

/// No credentials have been verified. No request claims are trusted.
final class AnonymousCaller<C> extends Caller<C> {
  /// Creates an anonymous caller without fabricated claims.
  const AnonymousCaller();
  @override
  bool get isAuthenticated => false;
  @override
  C? get claims => null;
  @override
  String? get userId => null;
}

/// A successful result from the configured credential verifier.
final class VerifiedCaller<C> extends Caller<C> {
  /// Rejects failed verification results.
  VerifiedCaller(this.authentication) {
    if (!authentication.isAuthenticated) {
      throw ArgumentError('VerifiedCaller requires successful authentication');
    }
  }

  /// The successful verifier result; claims retain their concrete type.
  final AuthenticationResult<C> authentication;
  @override
  bool get isAuthenticated => true;
  @override
  C? get claims => authentication.claims;
  @override
  String? get userId => authentication.userId;
}

/// Application-defined constraints for selecting rows AND counts before paging.
///
/// Implement this with domain-specific values such as a verified tenant ID.
/// Query code must apply this scope independently of untrusted request filters.
abstract interface class QueryScope {}

/// Explicitly selects all rows exposed by the application query handler.
final class UnrestrictedQueryScope implements QueryScope {
  /// Public and authentication-only policies use this scope.
  const UnrestrictedQueryScope();
}

/// The authorized caller and application scope passed to query code.
final class AuthorizedQuery<C> {
  /// Creates a query context after the resource policy has allowed it.
  const AuthorizedQuery({required this.caller, required this.scope});

  /// Anonymous or verified caller selected by the resource policy.
  final Caller<C> caller;

  /// Apply to both rows and counts before pagination.
  final QueryScope scope;
}

/// Input to an application policy. Switch exhaustively on its concrete type.
sealed class AuthorizationContext<T extends AggregateRoot<I>,
    I extends Identity, C> {
  const AuthorizationContext(this.caller, this.operation);

  /// The selected caller; anonymous policies receive a real anonymous state.
  final Caller<C> caller;

  /// The operation whose policy is being evaluated.
  final CrudOperation operation;
}

/// An item read, using detached persisted state.
final class ReadContext<T extends AggregateRoot<I>, I extends Identity, C>
    extends AuthorizationContext<T, I, C> {
  /// Authorizes the current stored aggregate before any body or ETag is returned.
  const ReadContext({required Caller<C> caller, required this.current})
      : super(caller, CrudOperation.read);

  /// Persisted state, never request-supplied ownership/visibility.
  final T current;
}

/// A collection read, including requests containing only pagination parameters.
final class QueryContext<T extends AggregateRoot<I>, I extends Identity, C>
    extends AuthorizationContext<T, I, C> {
  /// Copies filter parameters so policy evaluation cannot mutate the request.
  QueryContext({
    required Caller<C> caller,
    required Map<String, String> filters,
  })  : filters = Map.unmodifiable(filters),
        super(caller, CrudOperation.query);

  /// Untrusted filters, excluding normalized skip/take parameters.
  final Map<String, String> filters;
}

/// A create after server-owned preCreate normalization and identity validation.
final class CreateContext<T extends AggregateRoot<I>, I extends Identity, C>
    extends AuthorizationContext<T, I, C> {
  /// Authorizes the final proposal. Policies must not normalize it themselves.
  const CreateContext({required Caller<C> caller, required this.proposed})
      : super(caller, CrudOperation.create);

  /// Detached view of the actual proposed aggregate.
  final T proposed;
}

/// An update with separate, detached persisted and proposed snapshots.
final class UpdateContext<T extends AggregateRoot<I>, I extends Identity, C>
    extends AuthorizationContext<T, I, C> {
  /// Supplies both sides of the change; ownership checks start with current.
  const UpdateContext({
    required Caller<C> caller,
    required this.current,
    required this.proposed,
  }) : super(caller, CrudOperation.update);

  /// Persisted state before the attempted change.
  final T current;

  /// Request proposal, never a substitute for trusted current state.
  final T proposed;
}

/// A delete with the current stored aggregate rather than only its identity.
final class DeleteContext<T extends AggregateRoot<I>, I extends Identity, C>
    extends AuthorizationContext<T, I, C> {
  /// Supplies ownership/visibility without an application-side second lookup.
  const DeleteContext({required Caller<C> caller, required this.current})
      : super(caller, CrudOperation.delete);

  /// Detached persisted state being considered for removal.
  final T current;
}
