import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/authorization_context.dart';
import 'package:dddart_rest/src/authorization_result.dart';

/// Decides access using an explicit typed operation context.
///
/// Switch on ReadContext, QueryContext, CreateContext, UpdateContext and
/// DeleteContext. There are no permissive default hooks. Query decisions must
/// supply an application scope, including an explicit UnrestrictedQueryScope
/// when all rows are intentionally visible. Policies may allow anonymous callers.
// ignore: one_member_abstracts
abstract interface class AuthorizationHandler<T extends AggregateRoot<I>,
    I extends Identity, C> {
  /// Evaluates the selected operation before protected output or persistence.
  Future<AuthorizationResult> authorize(AuthorizationContext<T, I, C> context);
}
