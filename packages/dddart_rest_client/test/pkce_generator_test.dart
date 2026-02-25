import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart_rest_client/src/pkce_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PKCEGenerator', () {
    test('Property 1: PKCE Code Verifier Format', () {
      // Feature: cognito-oauth-fix
      // Property 1: PKCE Code Verifier Format
      // For any generated code verifier, the verifier must be a base64url-encoded
      // string of 43-128 characters containing only unreserved characters
      // [A-Z, a-z, 0-9, -, ., _, ~]

      for (var i = 0; i < 100; i++) {
        final verifier = PKCEGenerator.generateCodeVerifier();

        // Must be 43-128 characters
        expect(verifier.length, greaterThanOrEqualTo(43));
        expect(verifier.length, lessThanOrEqualTo(128));

        // Must contain only unreserved characters
        expect(verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
      }
    });

    test('Property 2: PKCE Code Challenge Computation', () {
      // Feature: cognito-oauth-fix
      // Property 2: PKCE Code Challenge Computation
      // For any code verifier, the code challenge must equal
      // Base64URL(SHA256(code_verifier)) with padding removed

      for (var i = 0; i < 100; i++) {
        final verifier = PKCEGenerator.generateCodeVerifier();
        final challenge = PKCEGenerator.generateCodeChallenge(verifier);

        // Manually compute expected challenge
        final bytes = utf8.encode(verifier);
        final digest = sha256.convert(bytes);
        final expected = base64Url.encode(digest.bytes).replaceAll('=', '');

        expect(challenge, equals(expected));

        // Challenge should not contain padding
        expect(challenge, isNot(contains('=')));

        // Challenge should be base64url characters only
        expect(challenge, matches(RegExp(r'^[A-Za-z0-9\-_]+$')));
      }
    });

    test('code verifiers are unique', () {
      final verifiers = <String>{};

      for (var i = 0; i < 100; i++) {
        final verifier = PKCEGenerator.generateCodeVerifier();
        verifiers.add(verifier);
      }

      // All verifiers should be unique
      expect(verifiers.length, equals(100));
    });

    test('state parameters are unique', () {
      final states = <String>{};

      for (var i = 0; i < 100; i++) {
        final state = PKCEGenerator.generateState();
        states.add(state);
      }

      // All states should be unique
      expect(states.length, equals(100));
    });

    test('state parameter format', () {
      for (var i = 0; i < 100; i++) {
        final state = PKCEGenerator.generateState();

        // Should be non-empty
        expect(state, isNotEmpty);

        // Should be base64url characters only
        expect(state, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));

        // Should not contain padding
        expect(state, isNot(contains('=')));
      }
    });

    test('same verifier produces same challenge', () {
      const verifier = 'test-verifier-123';

      final challenge1 = PKCEGenerator.generateCodeChallenge(verifier);
      final challenge2 = PKCEGenerator.generateCodeChallenge(verifier);

      expect(challenge1, equals(challenge2));
    });

    test('different verifiers produce different challenges', () {
      final verifier1 = PKCEGenerator.generateCodeVerifier();
      final verifier2 = PKCEGenerator.generateCodeVerifier();

      final challenge1 = PKCEGenerator.generateCodeChallenge(verifier1);
      final challenge2 = PKCEGenerator.generateCodeChallenge(verifier2);

      expect(challenge1, isNot(equals(challenge2)));
    });
  });
}
