import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authentication_result.dart';
import 'package:shelf/shelf.dart';

/// Verifies a credential independently of HTTP or any invocation provider.
// ignore: one_member_abstracts
abstract interface class CredentialVerifier<TClaims> {
  /// Verifies signature, lifetime, configured issuer/audience and typed claims.
  Future<AuthenticationResult<TClaims>> verifyCredential(String token);
}

/// Adapts the same credential verifier to Shelf's Bearer authentication contract.
abstract class TokenAuthenticationHandler<TClaims>
    extends AuthenticationHandler<TClaims>
    implements CredentialVerifier<TClaims> {
  @override
  Future<AuthenticationResult<TClaims>> authenticate(Request request) async {
    final header = request.headers['authorization'];
    if (header == null) {
      return AuthenticationResult.failure('Missing authorization header');
    }
    if (!header.startsWith('Bearer ')) {
      return AuthenticationResult.failure('Invalid token format');
    }
    return verifyCredential(header.substring(7).trim());
  }
}
