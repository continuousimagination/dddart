import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart_http/dddart_http.dart';
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

// Test verifier
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

// Helper to make HTTP requests
Future<HttpResponse> makeRequest({
  required String method,
  required String path,
  Map<String, String>? headers,
  String? body,
  int port = 8080,
}) async {
  final client = io.HttpClient();
  try {
    final request =
        await client.openUrl(method, Uri.parse('http://localhost:$port$path'));

    // Add headers
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }

    // Add body
    if (body != null) {
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    return HttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: responseBody,
    );
  } finally {
    client.close();
  }
}

class HttpResponse {
  HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final io.HttpHeaders headers;
  final String body;

  String? header(String name) {
    return headers.value(name);
  }
}

void main() {
  group('Webhook Integration Tests', () {
    group('End-to-end webhook processing with HttpServer', () {
      late HttpServer server;
      const port = 8090;

      tearDown(() async {
        await server.stop();
      });

      test('should process webhook request end-to-end', () async {
        var handlerCalled = false;
        TestPayload? receivedPayload;
        TestVerificationResult? receivedVerification;

        server = HttpServer(port: port);

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

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/test',
          headers: {'Content-Type': 'application/json'},
          body: '{"id": "123", "message": "test"}',
          port: port,
        );

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedPayload?.id, equals('123'));
        expect(receivedPayload?.message, equals('test'));
        expect(receivedVerification?.isValid, isTrue);
        expect(receivedVerification?.userId, equals('user-123'));
      });

      test('should return 401 for failed signature verification', () async {
        server = HttpServer(port: port);

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/secure',
          verifier: TestWebhookVerifier(
            shouldSucceed: false,
            errorMessage: 'Invalid signature',
          ),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            return Response.ok('Success');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/secure',
          headers: {'Content-Type': 'application/json'},
          body: '{"id": "123", "message": "test"}',
          port: port,
        );

        expect(response.statusCode, equals(401));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('Signature verification failed'));
        expect(json['message'], equals('Invalid signature'));
      });

      test('should handle raw string payload', () async {
        var handlerCalled = false;
        String? receivedBody;

        server = HttpServer(port: port);

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/raw',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            handlerCalled = true;
            receivedBody = body;
            return Response.ok('Received');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/raw',
          body: 'raw webhook data',
          port: port,
        );

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedBody, equals('raw webhook data'));
      });

      test('should handle form-encoded payload', () async {
        var handlerCalled = false;
        Map<String, String>? receivedForm;

        server = HttpServer(port: port);

        final webhook =
            WebhookResource<Map<String, String>, TestVerificationResult>(
          path: '/webhooks/form',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => Uri.splitQueryString(body),
          handler: (form, verification) async {
            handlerCalled = true;
            receivedForm = form;
            return Response.ok('Received');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/form',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'key1=value1&key2=value2',
          port: port,
        );

        expect(response.statusCode, equals(200));
        expect(handlerCalled, isTrue);
        expect(receivedForm?['key1'], equals('value1'));
        expect(receivedForm?['key2'], equals('value2'));
      });
    });

    group('Multiple webhook resources with different paths', () {
      late HttpServer server;
      const port = 8091;

      tearDown(() async {
        await server.stop();
      });

      test('should handle multiple webhooks on different paths', () async {
        var webhook1Called = false;
        var webhook2Called = false;
        var webhook3Called = false;

        server = HttpServer(port: port);

        // Register first webhook
        final webhook1 = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/service1',
          verifier: TestWebhookVerifier(userId: 'service1'),
          handler: (body, verification) async {
            webhook1Called = true;
            expect(verification.userId, equals('service1'));
            return Response.ok('Service 1 received');
          },
        );

        // Register second webhook
        final webhook2 = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/service2',
          verifier: TestWebhookVerifier(userId: 'service2'),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            webhook2Called = true;
            expect(verification.userId, equals('service2'));
            return Response(201, body: 'Service 2 created');
          },
        );

        // Register third webhook
        final webhook3 = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/service3/events',
          verifier: TestWebhookVerifier(userId: 'service3'),
          handler: (body, verification) async {
            webhook3Called = true;
            expect(verification.userId, equals('service3'));
            return Response.ok('Service 3 received');
          },
        );

        server
          ..registerWebhook(webhook1)
          ..registerWebhook(webhook2)
          ..registerWebhook(webhook3);

        await server.start();

        // Test webhook 1
        final response1 = await makeRequest(
          method: 'POST',
          path: '/webhooks/service1',
          body: 'test data 1',
          port: port,
        );

        expect(response1.statusCode, equals(200));
        expect(response1.body, equals('Service 1 received'));
        expect(webhook1Called, isTrue);

        // Test webhook 2
        final response2 = await makeRequest(
          method: 'POST',
          path: '/webhooks/service2',
          headers: {'Content-Type': 'application/json'},
          body: '{"id": "456", "message": "test"}',
          port: port,
        );

        expect(response2.statusCode, equals(201));
        expect(response2.body, equals('Service 2 created'));
        expect(webhook2Called, isTrue);

        // Test webhook 3
        final response3 = await makeRequest(
          method: 'POST',
          path: '/webhooks/service3/events',
          body: 'test data 3',
          port: port,
        );

        expect(response3.statusCode, equals(200));
        expect(response3.body, equals('Service 3 received'));
        expect(webhook3Called, isTrue);
      });

      test('should return 404 for non-existent webhook path', () async {
        server = HttpServer(port: port);

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/exists',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            return Response.ok('Success');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/does-not-exist',
          body: 'test',
          port: port,
        );

        expect(response.statusCode, equals(404));
      });
    });

    group('Error handling in integration', () {
      late HttpServer server;
      const port = 8092;

      tearDown(() async {
        await server.stop();
      });

      test('should handle deserialization errors', () async {
        server = HttpServer(port: port);

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/json',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            return Response.ok('Success');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/json',
          body: 'invalid json',
          port: port,
        );

        expect(response.statusCode, equals(400));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('Deserialization failed'));
      });

      test('should use custom deserialization error handler', () async {
        var errorHandlerCalled = false;

        server = HttpServer(port: port);

        final webhook = WebhookResource<TestPayload, TestVerificationResult>(
          path: '/webhooks/custom-error',
          verifier: TestWebhookVerifier(),
          deserializer: (body) => WebhookDeserializers.json(
            body,
            TestPayload.fromJson,
          ),
          handler: (payload, verification) async {
            return Response.ok('Success');
          },
          onDeserializationError: (body, error) async {
            errorHandlerCalled = true;
            return Response(
              422,
              body: jsonEncode({'custom': 'error', 'body': body}),
              headers: {'Content-Type': 'application/json'},
            );
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/custom-error',
          body: 'bad json',
          port: port,
        );

        expect(response.statusCode, equals(422));
        expect(errorHandlerCalled, isTrue);
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['custom'], equals('error'));
        expect(json['body'], equals('bad json'));
      });

      test('should handle handler exceptions', () async {
        server = HttpServer(port: port);

        final webhook = WebhookResource<String, TestVerificationResult>(
          path: '/webhooks/error',
          verifier: TestWebhookVerifier(),
          handler: (body, verification) async {
            throw Exception('Handler error');
          },
        );

        server.registerWebhook(webhook);
        await server.start();

        final response = await makeRequest(
          method: 'POST',
          path: '/webhooks/error',
          body: 'test',
          port: port,
        );

        expect(response.statusCode, equals(500));
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json['error'], equals('Internal server error'));
        expect(json['message'], equals('Handler threw exception'));
      });
    });
  });
}
