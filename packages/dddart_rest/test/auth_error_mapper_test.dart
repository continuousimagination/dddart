import 'dart:convert';

import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps missing authorization header error', () async {
      final error = Exception('Missing authorization header');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      expect(
          response.headers['Content-Type'], equals('application/problem+json'),);

      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['status'], equals(401));
      expect(body['title'], equals('Unauthorized'));
      expect(body['detail'], equals('Missing authorization header'));
    });

    test('maps invalid token format error', () async {
      final error = Exception('Invalid token format');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid token format'));
    });

    test('maps expired token error', () async {
      final error = Exception('Token has expired');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Token has expired'));
    });

    test('maps invalid signature error', () async {
      final error = Exception('Invalid token signature');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid token signature'));
    });

    test('maps invalid issuer error', () async {
      final error = Exception('Invalid token issuer');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid token issuer'));
    });

    test('maps invalid audience error', () async {
      final error = Exception('Invalid token audience');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid token audience'));
    });

    test('maps invalid refresh token error', () async {
      final error = Exception('Invalid refresh token');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid refresh token'));
    });

    test('maps refresh token expired error', () async {
      final error = Exception('Refresh token has expired');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Refresh token has expired'));
    });

    test('maps refresh token revoked error', () async {
      final error = Exception('Refresh token has been revoked');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Refresh token has been revoked'));
    });

    test('maps invalid device code error', () async {
      final error = Exception('Invalid device code');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid device code'));
    });

    test('maps device code expired error', () async {
      final error = Exception('Device code has expired');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Device code has expired'));
    });

    test('maps invalid credentials error', () async {
      final error = Exception('Invalid credentials');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Invalid credentials'));
    });

    test('maps unknown error to generic message', () async {
      final error = Exception('Some internal error with sensitive data');
      final response = AuthErrorMapper.mapToResponse(error);

      expect(response.statusCode, equals(401));
      final bodyString = await response.readAsString();
      final body = jsonDecode(bodyString) as Map<String, dynamic>;
      expect(body['detail'], equals('Authentication failed'));
    });

    test('sanitizes error messages with secrets', () {
      const message = 'Error: secret: abc123 key: xyz789';
      final sanitized = AuthErrorMapper.sanitizeErrorMessage(message);

      expect(sanitized, isNot(contains('abc123')));
      expect(sanitized, isNot(contains('xyz789')));
      expect(sanitized, contains('[REDACTED]'));
    });

    test('sanitizes error messages with signatures', () {
      const message = 'Invalid signature: abc123def456';
      final sanitized = AuthErrorMapper.sanitizeErrorMessage(message);

      expect(sanitized, isNot(contains('abc123def456')));
      expect(sanitized, contains('[REDACTED]'));
    });

    test('sanitizes error messages with file paths', () {
      const message = 'Error in /usr/local/app/auth.dart';
      final sanitized = AuthErrorMapper.sanitizeErrorMessage(message);

      expect(sanitized, isNot(contains('/usr/local/app/auth.dart')));
      expect(sanitized, contains('[PATH]'));
    });

    test('sanitizes error messages with stack traces', () {
      const message =
          'Error occurred\nStack trace:\n  at function1\n  at function2';
      final sanitized = AuthErrorMapper.sanitizeErrorMessage(message);

      expect(sanitized, isNot(contains('Stack trace')));
      expect(sanitized, isNot(contains('function1')));
    });
  });
}
