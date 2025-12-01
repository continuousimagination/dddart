import 'dart:convert';

import 'package:dddart_rest_client/src/auth_provider.dart';
import 'package:http/http.dart' as http;

/// HTTP client with automatic authentication
///
/// Wraps [http.Client] and automatically includes access tokens
/// from an [AuthProvider] in all requests.
class RestClient {
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

  /// GET request with automatic auth
  ///
  /// Automatically includes access token in Authorization header.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.get('/users/123');
  /// ```
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
    );
  }

  /// POST request with automatic auth
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.post(
  ///   '/users',
  ///   body: {'name': 'Alice', 'email': 'alice@example.com'},
  /// );
  /// ```
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };
    return _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PUT request with automatic auth
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.put(
  ///   '/users/123',
  ///   body: {'name': 'Alice Updated'},
  /// );
  /// ```
  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };
    return _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// DELETE request with automatic auth
  ///
  /// Automatically includes access token in Authorization header.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.delete('/users/123');
  /// ```
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      ...?headers,
    };
    return _httpClient.delete(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
    );
  }

  /// PATCH request with automatic auth
  ///
  /// Automatically includes access token in Authorization header.
  /// If [body] is provided, it will be JSON-encoded.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.patch(
  ///   '/users/123',
  ///   body: {'email': 'newemail@example.com'},
  /// );
  /// ```
  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final token = await authProvider.getAccessToken();
    final allHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };
    return _httpClient.patch(
      Uri.parse('$baseUrl$path'),
      headers: allHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Closes the underlying HTTP client
  void close() {
    _httpClient.close();
  }
}
