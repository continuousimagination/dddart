import 'dart:io';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:dddart_rest_client/src/oauth_callback_strategy.dart';

/// Callback strategy using a temporary local HTTP server
///
/// This strategy:
/// 1. Starts a local HTTP server on localhost
/// 2. Opens the authorization URL in the system's default browser
/// 3. Waits for the OAuth callback to the local server
/// 4. Displays success/error page in the browser
/// 5. Shuts down the server
///
/// Best for: CLI applications, desktop applications
/// Requires: Ability to bind to localhost and open browser
class LocalhostCallbackStrategy implements OAuthCallbackStrategy {
  /// Creates a localhost callback strategy
  ///
  /// - [port]: Port for the local HTTP server (default: 8080)
  /// - [path]: Path for the callback endpoint (default: '/callback')
  /// - [openBrowser]: Function to open browser (for testing)
  LocalhostCallbackStrategy({
    this.port = 8080,
    this.path = '/callback',
    Future<void> Function(String url)? openBrowser,
  }) : _openBrowser = openBrowser ?? _defaultOpenBrowser;

  /// Port for the local HTTP server
  final int port;

  /// Path for the callback endpoint
  final String path;

  /// Function to open browser
  final Future<void> Function(String url) _openBrowser;

  @override
  String getRedirectUri() => 'http://localhost:$port$path';

  @override
  Future<CallbackResult> waitForCallback({
    required String authorizationUrl,
    required String expectedState,
  }) async {
    HttpServer? server;
    try {
      // Start server on localhost only
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

      // Open browser
      print('\n🔐 Opening browser for authentication...');
      print('If browser does not open, visit: $authorizationUrl\n');

      try {
        await _openBrowser(authorizationUrl);
      } catch (e) {
        // Browser opening failed, user will use printed URL
        print('Could not open browser automatically: $e');
      }

      print('Waiting for authentication...');

      // Wait for callback
      await for (final request in server) {
        if (request.uri.path == path) {
          final code = request.uri.queryParameters['code'];
          final state = request.uri.queryParameters['state'];
          final error = request.uri.queryParameters['error'];
          final errorDesc = request.uri.queryParameters['error_description'];

          // Send HTML response
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_getCallbackHtml(error == null));
          await request.response.close();

          return CallbackResult(
            code: code ?? '',
            state: state ?? '',
            error: error,
            errorDescription: errorDesc,
          );
        } else {
          // 404 for non-callback paths
          request.response
            ..statusCode = 404
            ..write('Not found');
          await request.response.close();
        }
      }

      throw AuthenticationException(
        'Server closed without receiving callback',
      );
    } finally {
      await server?.close();
    }
  }

  /// Default browser opener implementation
  static Future<void> _defaultOpenBrowser(String url) async {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      throw UnsupportedError('Cannot open browser on this platform');
    }
  }

  /// Returns HTML to display in browser after callback
  String _getCallbackHtml(bool success) {
    if (success) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <title>Authentication Successful</title>
  <style>
    body { font-family: system-ui; text-align: center; padding: 50px; }
    .success { color: #22c55e; font-size: 48px; }
    h1 { color: #333; }
    p { color: #666; }
  </style>
</head>
<body>
  <div class="success">✓</div>
  <h1>Authentication Successful!</h1>
  <p>You can close this window and return to your terminal.</p>
</body>
</html>
''';
    } else {
      return '''
<!DOCTYPE html>
<html>
<head>
  <title>Authentication Failed</title>
  <style>
    body { font-family: system-ui; text-align: center; padding: 50px; }
    .error { color: #ef4444; font-size: 48px; }
    h1 { color: #333; }
    p { color: #666; }
  </style>
</head>
<body>
  <div class="error">✗</div>
  <h1>Authentication Failed</h1>
  <p>Please check your terminal for error details.</p>
</body>
</html>
''';
    }
  }
}
