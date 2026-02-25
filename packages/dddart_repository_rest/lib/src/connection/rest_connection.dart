import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;

/// Manages HTTP client and authentication for REST API communication.
///
/// This class encapsulates the configuration needed to communicate with
/// a REST API, including the base URL and optional authentication.
///
/// ## Basic Usage (No Authentication)
///
/// ```dart
/// final connection = RestConnection(
///   baseUrl: 'https://api.example.com',
/// );
///
/// final userRepo = UserRestRepository(connection);
/// // Use repository...
///
/// connection.dispose(); // Clean up when done
/// ```
///
/// ## With Authentication
///
/// ```dart
/// final authProvider = DeviceFlowAuthProvider(
///   clientId: 'your-client-id',
///   authorizationEndpoint: 'https://auth.example.com/authorize',
///   tokenEndpoint: 'https://auth.example.com/token',
/// );
///
/// final connection = RestConnection(
///   baseUrl: 'https://api.example.com',
///   authProvider: authProvider,
/// );
/// ```
///
/// ## Connection Sharing
///
/// Multiple repositories can share the same connection to reuse the
/// HTTP client and authentication state:
///
/// ```dart
/// final connection = RestConnection(baseUrl: 'https://api.example.com');
///
/// final userRepo = UserRestRepository(connection);
/// final orderRepo = OrderRestRepository(connection);
/// // Both repositories share the same HTTP client
/// ```
class RestConnection {
  /// Creates a REST connection.
  ///
  /// [baseUrl] - The base URL of the REST API (e.g., 'https://api.example.com').
  /// Must not include a trailing slash.
  ///
  /// [authProvider] - Optional authentication provider for obtaining access
  /// tokens. If null, requests will be made without authentication.
  ///
  /// [httpClient] - Optional HTTP client. If null, creates a new [http.Client].
  /// Useful for testing or custom HTTP client configuration.
  RestConnection({
    required this.baseUrl,
    this.authProvider,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _client = authProvider != null
            ? RestClient(
                baseUrl: baseUrl,
                authProvider: authProvider,
                httpClient: httpClient,
              )
            : null;

  /// The base URL of the REST API.
  ///
  /// All HTTP requests will be made relative to this URL.
  /// Example: 'https://api.example.com'
  final String baseUrl;

  /// Optional authentication provider for obtaining access tokens.
  ///
  /// If null, requests will be made without authentication headers.
  final AuthProvider? authProvider;

  /// The underlying HTTP client.
  ///
  /// Used for making unauthenticated requests when no auth provider
  /// is configured.
  final http.Client _httpClient;

  /// The REST client for authenticated requests.
  ///
  /// Only created when an auth provider is configured.
  final http.Client? _client;

  /// Gets the HTTP client for making requests.
  ///
  /// Returns the authenticated [RestClient] if an auth provider is
  /// configured, otherwise returns the basic HTTP client.
  ///
  /// Both implement [http.Client] interface, so callers don't need
  /// to know which one they're using.
  http.Client get client => _client ?? _httpClient;

  /// Disposes the connection and releases resources.
  ///
  /// Closes the underlying HTTP client. After calling this method,
  /// the connection should not be used for any further requests.
  ///
  /// All repositories using this connection should be considered
  /// disposed as well.
  void dispose() {
    client.close();
  }
}
