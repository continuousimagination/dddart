import 'dart:io';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:dddart_rest_client/src/oauth_callback_strategy.dart';

/// Callback strategy where user manually enters the authorization code
///
/// This strategy:
/// 1. Prints the authorization URL for the user to open
/// 2. Provides instructions to copy the authorization code
/// 3. Prompts the user to paste the code or full callback URL
/// 4. Extracts the code and state from the input
///
/// Best for: Web applications, environments without browser access,
///           cross-platform scenarios
/// Requires: User interaction via stdin/stdout
class ManualCallbackStrategy implements OAuthCallbackStrategy {
  /// Creates a manual callback strategy
  ///
  /// - [redirectUri]: The redirect URI configured in the OAuth provider
  ManualCallbackStrategy({
    required this.redirectUri,
  });

  /// The redirect URI configured in the OAuth provider
  final String redirectUri;

  @override
  String getRedirectUri() => redirectUri;

  @override
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  }) async {
    print('\n🔐 Manual Authentication Required');
    print('=' * 60);
    print('\n1. Open this URL in your browser:');
    print('   $authorizationUrl\n');
    print('2. After authenticating, you will be redirected to:');
    print('   $redirectUri?code=...\n');
    print('3. Copy the ENTIRE URL from your browser address bar');
    print('   OR just the authorization code\n');
    print('=' * 60);
    print('\nPaste here and press Enter:');

    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) {
      throw AuthenticationException('No input provided');
    }

    // Try to parse as full URL first
    try {
      final uri = Uri.parse(input);
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];
      final errorDesc = uri.queryParameters['error_description'];

      if (code != null || error != null) {
        return CallbackResult(
          code: code ?? '',
          state: state ?? expectedState,
          error: error,
          errorDescription: errorDesc,
        );
      }
    } catch (e) {
      // Not a valid URL, treat as just the code
    }

    // Treat input as just the authorization code
    return CallbackResult(
      code: input,
      state: expectedState,
    );
  }
}
