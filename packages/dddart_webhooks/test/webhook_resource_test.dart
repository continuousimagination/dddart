import 'dart:convert';

import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Test verification result
class TestVerificationResult extends WebhookVerificationResult {
  const TestVerificationResult({
    required super.isValid,
    super.errorMessage,
    this.userId,
  });

  final String? userId;
}

// Test verifier that can be configured to succeed or fail
class TestWebhookVerifier extends WebhookVerifier<TestVerificationResult> {
  TestWebhookVerifier({
    this.shouldSucceed = true,
    this.errorMessage,
    this.userId,
  });

  final bool shouldSucceed;
  final String? errorMessage;
  final String? userId;

  @override
  Future<TestVerificationResult> verify(Request request, String body) async {
    return TestVerificationResult(
      isValid: shouldSucceed,
      errorMessage: errorMessage,
      userId: userId,
    );
  }
}

// Test payload model
class TestPayload {
  TestPayload({required this.id, required this.message});

  factory TestPayload.fromJson(Map<String, dynamic> json) {
    return TestPayload(
      id: json['id'] as String,
      message: json['message'] as String,
    );
  }

  final String id;
  final String message;
}

void main() {
  group('WebhookResource', () {
    group('handleRequest', () {
      test('should process valid webhook with JSON payload', () async {
        var handlerCalled = false;
        TestPayload? receivedPayload;
        TestVerificationResult? receivedVerification;

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(userId: 'user-123'),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            handlerCalled = true;
            receivedPayload = payload;
            receivedVerification = verification;
            return Response.ok('Success');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: '{"id": "123", "message": "test"}',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedPayload?.id, equals('123'));
        expect(receivedPayload?.message, equals('test'));
        expect(receivedVerification?.isValid, isTrue);
        expect(receivedVerification?.userId, equals('user-123'));
      });

      test('should process webhook with raw string payload', () async {
        var handlerCalled = false;
        String? receivedBody;

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/raw',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            handlerCalled = true;
            receivedBody = body;
            return Response.ok('Received');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/raw'),
          body: 'raw webhook data',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedBody, equals('raw webhook data'));
      });

      test('should return 401 when signature verification fails', () async {
        var handlerCalled = false;

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(
            shouldSucceed: false,
            errorMessage: 'Invalid signature',
          ),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            handlerCalled = true;
            return Response.ok('Success');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: '{"id": "123", "message": "test"}',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(401));
        expect(handlerCalled, isFalse);

        final responseBody = await response.readAsString();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        expect(json['error'], equals('Signature verification failed'));
        expect(json['message'], equals('Invalid signature'));
      });

      test('should return 400 when deserialization fails', () async {
        var handlerCalled = false;

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            handlerCalled = true;
            return Response.ok('Success');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: 'invalid json',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(400));
        expect(handlerCalled, isFalse);

        final responseBody = await response.readAsString();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        expect(json['error'], equals('Deserialization failed'));
      });

      test('should use custom error handler for deserialization failures',
          () async {
        var handlerCalled = false;
        var errorHandlerCalled = false;
        String? errorBody;
        Object? errorException;

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            handlerCalled = true;
            return Response.ok('Success');
          },
          onDeserializationError: (body, error) async {
            errorHandlerCalled = true;
            errorBody = body;
            errorException = error;
            return Response(
              422,
              body: jsonEncode({'custom': 'error', 'body': body}),
              headers: {'Content-Type': 'application/json'},
            );
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: 'bad json',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(422));
        expect(handlerCalled, isFalse);
        expect(errorHandlerCalled, isTrue);
        expect(errorBody, equals('bad json'));
        expect(errorException, isA<FormatException>());

        final responseBody = await response.readAsString();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        expect(json['custom'], equals('error'));
        expect(json['body'], equals('bad json'));
      });

      test('should return 500 when handler throws exception', () async {
        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            throw Exception('Handler error');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: '{"id": "123", "message": "test"}',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(500));

        final responseBody = await response.readAsString();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        expect(json['error'], equals('Internal server error'));
        expect(json['message'], equals('Handler threw exception'));
      });

      test('should pass verification result to handler', () async {
        TestVerificationResult? receivedVerification;

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(userId: 'user-456'),
          handler: (body, verification) async {
            receivedVerification = verification;
            return Response.ok('Success');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: 'test data',
        );

        await webhook.handleRequest(request);

        expect(receivedVerification?.isValid, isTrue);
        expect(receivedVerification?.userId, equals('user-456'));
      });

      test('should handle empty request body', () async {
        var handlerCalled = false;
        String? receivedBody;

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            handlerCalled = true;
            receivedBody = body;
            return Response.ok('Success');
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: '',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedBody, equals(''));
      });

      test('should return handler response to webhook provider', () async {
        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            return Response(
              201,
              body: jsonEncode({'status': 'created', 'id': '789'}),
              headers: {'Content-Type': 'application/json'},
            );
          },
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/webhooks/test'),
          body: 'test',
        );

        final response = await webhook.handleRequest(request);

        expect(response.statusCode, equals(201));
        final responseBody = await response.readAsString();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        expect(json['status'], equals('created'));
        expect(json['id'], equals('789'));
      });
    });

    group('properties', () {
      test('should expose path property', () {
        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/custom',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async => Response.ok('OK'),
        );

        expect(webhook.path, equals('/webhooks/custom'));
      });

      test('should expose verifier property', () {
        final verifier = TestWebhookVerifier();
        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: verifier,
          handler: (body, verification) async => Response.ok('OK'),
        );

        expect(webhook.verifier, same(verifier));
      });

      test('should expose handler property', () {
        Future<Response> handler(String body, TestVerificationResult v) async {
          return Response.ok('OK');
        }

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/test',
          verifier: TestWebhookVerifier(),
          handler: handler,
        );

        expect(webhook.handler, same(handler));
      });
    });
  });
}
