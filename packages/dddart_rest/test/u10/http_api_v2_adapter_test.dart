/// Typed HTTP API v2 mapping preserves bytes and invocation context.
library;

import 'dart:convert';
import 'package:dddart_rest/dddart_lambda.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Map<String, Object?> _event({
  String method = 'GET',
  Object? body,
  bool encoded = false,
}) => {
  'version': '2.0',
  'rawPath': '/records/a%2Fb',
  'rawQueryString': 'x=1&x=2',
  'headers': {'host': 'example.invalid', 'authorization': 'first,second'},
  'cookies': ['a=1', 'b=2'],
  'requestContext': {
    'apiId': 'api',
    'stage': 'test',
    'requestId': 'gateway-id',
    'http': {'method': method, 'path': '/records/a/b', 'protocol': 'HTTP/1.1'},
  },
  if (body != null) 'body': body,
  'isBase64Encoded': encoded,
};
void main() {
  final context = LambdaInvocationContext(
    requestId: 'runtime-id',
    deadline: DateTime.utc(2030),
    invocationId: 'attempt-id',
  );
  test(
    'preserves raw repeated query, cookies and distinct request identifiers',
    () async {
      final adapter = HttpApiV2Adapter((request) async {
        expect(request.requestedUri.toString(), contains('/records/a%2Fb?'));
        expect(request.requestedUri.host, 'example.invalid');
        expect(request.requestedUri.toString(), isNot(contains('%252F')));
        expect(request.requestedUri.query, 'x=1&x=2');
        expect(request.headers['cookie'], 'a=1; b=2');
        expect(request.headers['authorization'], 'first,second');
        final invocation =
            request.context[LambdaInvocationContext.contextKey]!
                as LambdaInvocationContext;
        expect(invocation.requestId, 'runtime-id');
        expect(invocation.invocationId, 'attempt-id');
        expect(invocation.deadline, context.deadline);
        final input =
            request.context[HttpApiV2Request.contextKey]! as HttpApiV2Request;
        expect(input.requestId, 'gateway-id');
        expect(input.apiId, 'api');
        expect(input.stage, 'test');
        expect(input.rawPath, '/records/a%2Fb');
        return Response.ok('ok');
      });
      final response = await adapter.handle(_event(), context: context);
      expect(response['statusCode'], 200);
      expect(response['body'], 'ok');
      expect(response['isBase64Encoded'], isFalse);
    },
  );
  test(
    'provider domain name determines authority without altering the raw path',
    () async {
      final event = _event();
      (event['requestContext']! as Map<String, Object?>)['domainName'] =
          'gateway.invalid';
      final adapter = HttpApiV2Adapter((request) async {
        expect(request.requestedUri.host, 'gateway.invalid');
        return Response.ok('ok');
      });
      expect(
        (await adapter.handle(event, context: context))['statusCode'],
        200,
      );
    },
  );
  test('maps binary request/response and repeated Set-Cookie values', () async {
    final adapter = HttpApiV2Adapter((request) async {
      expect(await request.read().expand((chunk) => chunk).toList(), [
        0,
        255,
        1,
      ]);
      return Response.ok(
        [255, 0],
        headers: {
          'set-cookie': ['a=1', 'b=2'],
        },
      );
    });
    final response = await adapter.handle(
      _event(method: 'POST', body: base64Encode([0, 255, 1]), encoded: true),
      context: context,
    );
    expect(response['isBase64Encoded'], isTrue);
    expect(base64Decode(response['body']! as String), [255, 0]);
    expect(response['cookies'], ['a=1', 'b=2']);
  });
  test(
    'rejects malformed envelopes/base64 without invoking handler or echoing values',
    () async {
      var calls = 0;
      final adapter = HttpApiV2Adapter((_) async {
        calls++;
        return Response.ok('ok');
      });
      for (final event in [
        <String, Object?>{},
        {..._event(), 'version': '1.0'},
        _event(body: 42),
        _event(body: String.fromCharCode(0xd800)),
        _event(body: 'restricted-payload%%', encoded: true),
        {..._event(), 'rawPath': 'https://evil.invalid/'},
        {
          ..._event(),
          'headers': {
            'authorization': ['a', 'b'],
          },
        },
      ]) {
        final response = await adapter.handle(event, context: context);
        expect(response['statusCode'], 400);
        expect(response.toString(), isNot(contains('restricted-payload')));
      }
      expect(calls, 0);
    },
  );
  test('handler failures propagate for runtime error reporting', () async {
    final adapter = HttpApiV2Adapter(
      (_) async => throw StateError('synthetic'),
    );
    await expectLater(
      adapter.handle(_event(), context: context),
      throwsStateError,
    );
  });
}
