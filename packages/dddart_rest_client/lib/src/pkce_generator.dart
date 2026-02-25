import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generates PKCE code verifier and challenge
///
/// PKCE (Proof Key for Code Exchange) is a security extension for OAuth 2.0
/// that allows public clients (without client secrets) to securely perform
/// authorization code flow.
///
/// This class is internal to the package and should not be used directly.
class PKCEGenerator {
  /// Generates a cryptographically random code verifier
  ///
  /// Per RFC 7636, the code verifier is a random string of 43-128
  /// characters from the unreserved character set [A-Z, a-z, 0-9, -, ., _, ~]
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generates code challenge from verifier
  ///
  /// Per RFC 7636, the code challenge is:
  /// BASE64URL(SHA256(ASCII(code_verifier)))
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates random state parameter for CSRF protection
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
