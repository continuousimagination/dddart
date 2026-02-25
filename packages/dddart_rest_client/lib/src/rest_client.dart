import 'dart:convert';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:http/http.dart' as http;

/// HTTP client with automatic authentication
///
/// Extends [http.Client] and automatically includes access tokens
/// from an [AuthProvider] in all requests.
class RestClient extends http.BaseClient {
  /// Creates a REST client
  ///
  /// - [baseUrl]: Base URL for all requests (e.g., 'https://api.example.com')
  /// - [authProvider]: Provider for authentication tokens
  /// - [httpClient]: Optional HTTP client (defaults to [http.Client])
  RestClient({
    required this.baseUrl,
    required this.authProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Base URL for all requests
  final String baseUrl;

  /// Authentication provider
  final AuthProvider authProvider;

  /// Underlying HTTP client
  final http.Client _httpClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Add authentication header
    // Use ID token for JWT-based authentication (OIDC providers like Cognito)
    // Falls back to access token for non-OIDC providers
    final token = await authProvider.getIdToken();
    request.headers['Authorization'] = 'Bearer $token';
    
    return _httpClient.send(request);
  }

  @override
  void close() {
    _httpClient.close();
  }

  // Convenience methods that take path strings instead of full URIs

  /// GET request with automatic auth using path string
  ///
  /// Automatically includes access token in Authorization header.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.getPath('/users/123');
  /// ```
  Future<http.Response> getPath(
    String path, {
    Map<String, String>? headers,
  }) async {
    return get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  /// POST request with automatic auth using path string
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.postPath(
  ///   '/users',
  ///   body: {'name': 'Alice', 'email': 'alice@example.com'},
  /// );
  /// ```
  Future<http.Response> postPath(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final allHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return post(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PUT request with automatic auth using path string
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.putPath(
  ///   '/users/123',
  ///   body: {'name': 'Alice Updated'},
  /// );
  /// ```
  Future<http.Response> putPath(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final allHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return put(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// DELETE request with automatic auth using path string
  ///
  /// Automatically includes access token in Authorization header.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.deletePath('/users/123');
  /// ```
  Future<http.Response> deletePath(
    String path, {
    Map<String, String>? headers,
  }) async {
    return delete(Uri.parse('$baseUrl$path'), headers: headers);
  }

  /// PATCH request with automatic auth using path string
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.patchPath(
  ///   '/users/123',
  ///   body: {'email': 'newemail@example.com'},
  /// );
  /// ```
  Future<http.Response> patchPath(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final allHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return patch(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
