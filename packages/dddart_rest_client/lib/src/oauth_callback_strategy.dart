import 'package:dddart_rest_client/src/auth_provider.dart';

/// Strategy for handling OAuth authorization callbacks
///
/// Different platforms require different approaches to receive the
/// authorization code from the OAuth provider:
/// - CLI/Desktop: Local HTTP server (LocalhostCallbackStrategy)
/// - Web: Manual code entry (ManualCallbackStrategy)
/// - Mobile: Custom URL schemes (CustomSchemeCallbackStrategy)
abstract class OAuthCallbackStrategy {
  /// Gets the redirect URI for this strategy
  ///
  /// This URI must match what's configured in the OAuth provider
  /// (e.g., Cognito app client settings).
  String getRedirectUri();

  /// Waits for and retrieves the authorization code
  ///
  /// This method should:
  /// 1. Display the authorization URL to the user (or open browser)
  /// 2. Wait for the OAuth callback with the authorization code
  /// 3. Extract and return the code and state parameters
  ///
  /// Parameters:
  /// - [authorizationUrl]: The complete OAuth authorization URL
  /// - [expectedState]: The state parameter sent in the request
  ///
  /// Returns a [CallbackResult] containing the authorization code and state.
  ///
  /// Throws [AuthenticationException] if:
  /// - User cancels or times out
  /// - OAuth provider returns an error
  /// - Callback handling fails
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  });
}

/// Result from OAuth callback
class CallbackResult {
  /// Creates a callback result
  CallbackResult({
    required this.code,
    required this.state,
    this.error,
    this.errorDescription,
  });

  /// Authorization code from OAuth provider
  final String code;

  /// State parameter for CSRF protection
  final String state;

  /// Error code if OAuth provider returned an error
  final String? error;

  /// Human-readable error description
  final String? errorDescription;

  /// Whether the callback indicates an error
  bool get hasError => error != null;
}
