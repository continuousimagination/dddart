/// Uses the actual pinned SDK with injected transport, never AWS resources.
library;

import 'dart:async';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class _Transport extends http.BaseClient {
  _Transport(this.reply);
  final Future<http.StreamedResponse> Function(http.BaseRequest) reply;
  int sends = 0;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    return reply(request);
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  DynamoConnection connect(_Transport transport) => DynamoConnection(
    region: 'us-east-1',
    endpoint: 'https://example.invalid',
    credentials: AwsClientCredentials(
      accessKey: 'test-access',
      secretKey: 'test-secret',
      sessionToken: 'test-session',
    ),
    httpClient: transport,
  );
  test('provided session credentials and transport are used once', () async {
    final transport = _Transport((request) async {
      expect(
        request.headers['X-Amz-Security-Token'] ??
            request.headers['x-amz-security-token'],
        'test-session',
      );
      return http.StreamedResponse(Stream.value('{}'.codeUnits), 200);
    });
    final connection = connect(transport);
    await connection.client.putItem(
      tableName: 'records',
      item: {'id': AttributeValue(s: 'test')},
    );
    expect(transport.sends, 1);
    connection.dispose();
    expect(transport.closed, isFalse);
  });
  test('lost response after dispatched write is never replayed', () async {
    final transport = _Transport(
      (_) async => http.StreamedResponse(
        Stream.error(http.ClientException('synthetic lost response')),
        200,
      ),
    );
    final connection = connect(transport);
    await expectLater(
      connection.client.putItem(
        tableName: 'records',
        item: {'id': AttributeValue(s: 'test')},
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(transport.sends, 1);
    connection.dispose();
  });
  test('transport timeout is never replayed', () async {
    final transport = _Transport(
      (_) async => throw TimeoutException('synthetic'),
    );
    final connection = connect(transport);
    await expectLater(
      connection.client.putItem(
        tableName: 'records',
        item: {'id': AttributeValue(s: 'test')},
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(transport.sends, 1);
    connection.dispose();
  });
  test('provider throttling or server error is never replayed', () async {
    final transport = _Transport(
      (_) async => http.StreamedResponse(
        Stream.value(
          '{"__type":"InternalServerError","message":"synthetic"}'.codeUnits,
        ),
        500,
      ),
    );
    final connection = connect(transport);
    await expectLater(
      connection.client.putItem(
        tableName: 'records',
        item: {'id': AttributeValue(s: 'test')},
      ),
      throwsA(isA<Exception>()),
    );
    expect(transport.sends, 1);
    connection.dispose();
  });
}
