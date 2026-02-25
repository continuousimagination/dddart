import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Maps authentication errors to RFC 7807 Problem Details responses
///
/// This class provides centralized error handling for authentication failures,
/// ensuring consistent error responses across all authentication endpoints.
/// All error messages are sanitized to prevent leakage of sensitive information
/// such as signing secrets, expected signatures, or internal system details.
///
/// Example:
/// ```dart
/// try {
///   // Authentication logic
/// } catch (e) {
///   return AuthErrorMapper.mapToResponse(e);
/// }
/// ```
class AuthErrorMapper {
  /// Maps an exception to an appropriate HTTP response
  ///
  /// Converts authentication-related exceptions into RFC 7807 formatted
  /// responses with appropriate HTTP status codes. Unknown exceptions are
  /// mapped to 401 Unauthorized with a generic message.
  ///
  /// Parameters:
  /// - [error]: The exception or error object to map
  ///
  /// Returns: A [Response] with appropriate status code and RFC 7807 body
  static Response mapToResponse(Object error) {
    final errorMessage = error.toString();

    // Map specific error messages to appropriate responses
    if (errorMessage.contains('Missing authorization header')) {
      return _unauthorized('Missing authorization header');
    }

    if (errorMessage.contains('Invalid token format')) {
      return _unauthorized('Invalid token format');
    }

    if (errorMessage.contains('Refresh token has expired')) {
      return _unauthorized('Refresh token has expired');
    }

    if (errorMessage.contains('Device code has expired')) {
      return _unauthorized('Device code has expired');
    }

    if (errorMessage.contains('Token has expired') ||
        errorMessage.contains('expired')) {
      return _unauthorized('Token has expired');
    }

    if (errorMessage.contains('Invalid token signature') ||
        errorMessage.contains('signature')) {
      return _unauthorized('Invalid token signature');
    }

    if (errorMessage.contains('Invalid token issuer') ||
        errorMessage.contains('issuer')) {
      return _unauthorized('Invalid token issuer');
    }

    if (errorMessage.contains('Invalid token audience') ||
        errorMessage.contains('audience')) {
      return _unauthorized('Invalid token audience');
    }

    if (errorMessage.contains('Invalid refresh token') ||
        errorMessage.contains('refresh token')) {
      return _unauthorized('Invalid refresh token');
    }

    if (errorMessage.contains('Refresh token has expired')) {
      return _unauthorized('Refresh token has expired');
    }

    if (errorMessage.contains('Refresh token has been revoked') ||
        errorMessage.contains('revoked')) {
      return _unauthorized('Refresh token has been revoked');
    }

    if (errorMessage.contains('Invalid device code') ||
        errorMessage.contains('device code')) {
      return _unauthorized('Invalid device code');
    }

    if (errorMessage.contains('Device code has expired')) {
      return _unauthorized('Device code has expired');
    }

    if (errorMessage.contains('Invalid credentials')) {
      return _unauthorized('Invalid credentials');
    }

    // Default to generic unauthorized message
    // This prevents leaking internal error details
    return _unauthorized('Authentication failed');
  }

  /// Creates a 401 Unauthorized response with RFC 7807 format
  ///
  /// Parameters:
  /// - [detail]: Human-readable error message
  ///
  /// Returns: A [Response] with status 401 and RFC 7807 formatted body
  static Response _unauthorized(String detail) {
    return Response(
      401,
      headers: {
        'Content-Type': 'application/problem+json',
        'WWW-Authenticate': 'Bearer realm="API"',
      },
      body: jsonEncode({
        'type': 'about:blank',
        'title': 'Unauthorized',
        'status': 401,
        'detail': detail,
      }),
    );
  }

  /// Sanitizes error messages to prevent information leakage
  ///
  /// Removes sensitive information from error messages such as:
  /// - Signing secrets
  /// - Expected vs actual signatures
  /// - Internal system paths or configurations
  /// - Stack traces
  ///
  /// Parameters:
  /// - [message]: The original error message
  ///
  /// Returns: A sanitized error message safe for client consumption
  static String sanitizeErrorMessage(String message) {
    // Remove common sensitive patterns
    var sanitized = message;

    // Remove anything that looks like a secret or key
    sanitized = sanitized.replaceAll(
      RegExp(r'secret[:\s=]+[^\s]+', caseSensitive: false),
      'secret: [REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'key[:\s=]+[^\s]+', caseSensitive: false),
      'key: [REDACTED]',
    );

    // Remove anything that looks like a signature
    sanitized = sanitized.replaceAll(
      RegExp(r'signature[:\s=]+[^\s]+', caseSensitive: false),
      'signature: [REDACTED]',
    );

    // Remove file paths
    sanitized = sanitized.replaceAll(RegExp(r'(/[^\s]+)+'), '[PATH]');

    // Remove stack traces
    if (sanitized.contains('Stack trace:')) {
      sanitized = sanitized.substring(0, sanitized.indexOf('Stack trace:'));
    }

    return sanitized.trim();
  }
}
