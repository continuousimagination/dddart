/// Rejection-only ingress checks happen before decoding and never grant access.
library;

import 'dart:convert';
import 'package:dddart_rest/dddart_lambda.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Map<String, Object?> _event() => {
  'version': '2.0',
  'rawPath': '/probe',
  'headers': <String, String>{},
  'requestContext': {
    'http': {'method': 'GET'},
  },
};
void main() {
  final context = LambdaInvocationContext(
    requestId: 'request',
    deadline: DateTime.utc(2030),
  );
  test(
    'rejection wins before malformed oversized body parsing or handler',
    () async {
      var guards = 0;
      var calls = 0;
      final adapter = HttpApiV2Adapter(
        (request) {
          calls++;
          return Response.ok('unexpected');
        },
        preflight: (event, invocation) {
          guards++;
          expect(invocation, same(context));
          expect(() => event['extra'] = true, throwsUnsupportedError);
          return Response(
            413,
            body: 'rejected',
            headers: {'cache-control': 'no-store'},
          );
        },
      );
      final result = await adapter.handle({
        ..._event(),
        'isBase64Encoded': true,
        'body': '%' * 4096,
      }, context: context);
      expect(result['statusCode'], 413);
      expect(result['body'], 'rejected');
      expect(result['headers'], containsPair('cache-control', 'no-store'));
      expect(guards, 1);
      expect(calls, 0);
    },
  );
  test(
    'null acceptance still runs validation and ordinary authentication',
    () async {
      var calls = 0;
      final adapter = HttpApiV2Adapter((request) {
        calls++;
        return Response(401);
      }, preflight: (_, _) => null);
      expect(
        (await adapter.handle(_event(), context: context))['statusCode'],
        401,
      );
      expect(
        (await adapter.handle({
          ..._event(),
          'isBase64Encoded': true,
          'body': '%',
        }, context: context))['statusCode'],
        400,
      );
      expect(calls, 1);
    },
  );
  test(
    'success, redirects and callback exceptions fail closed safely',
    () async {
      for (final status in [200, 302, -1]) {
        var calls = 0;
        final adapter = HttpApiV2Adapter(
          (_) {
            calls++;
            return Response.ok('unexpected');
          },
          preflight: (_, _) {
            if (status < 0) throw StateError('restricted-preflight-value');
            return Response(status, body: 'restricted-preflight-value');
          },
        );
        await expectLater(
          adapter.handle(_event(), context: context),
          throwsA(
            isA<StateError>().having(
              (error) => error.toString(),
              'safe error',
              isNot(contains('restricted-preflight-value')),
            ),
          ),
        );
        expect(calls, 0);
      }
    },
  );
  test(
    'direct and initialized runtimes forward one rejection response',
    () async {
      for (final initialize in [false, true]) {
        var calls = 0;
        var guards = 0;
        final posts = <http.Request>[];
        final client = MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({..._event(), 'body': '%', 'isBase64Encoded': true}),
              200,
              headers: {
                'lambda-runtime-aws-request-id': 'request',
                'lambda-runtime-deadline-ms': '1893456000000',
              },
            );
          }
          posts.add(request);
          return http.Response('', 202);
        });
        Response? guard(
          Map<String, Object?> event,
          LambdaInvocationContext context,
        ) {
          guards++;
          return Response(413);
        }

        Response handler(Request request) {
          calls++;
          return Response.ok('unexpected');
        }

        final runtime = initialize
            ? await LambdaRuntime.initialize(
                initializeHandler: () => handler,
                client: client,
                endpoint: Uri.parse('http://runtime.invalid'),
                preflight: guard,
              )
            : LambdaRuntime(
                handler: handler,
                client: client,
                endpoint: Uri.parse('http://runtime.invalid'),
                preflight: guard,
              );
        await runtime.runOnce();
        expect(posts, hasLength(1));
        expect(posts.single.url.path, endsWith('/response'));
        expect((jsonDecode(posts.single.body) as Map)['statusCode'], 413);
        expect(guards, 1);
        expect(calls, 0);
        client.close();
      }
    },
  );
  test('callback failure uses safe Runtime API invocation error', () async {
    final posts = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(_event()),
          200,
          headers: {
            'lambda-runtime-aws-request-id': 'request',
            'lambda-runtime-deadline-ms': '1893456000000',
          },
        );
      }
      posts.add(request);
      return http.Response('', 202);
    });
    final runtime = LambdaRuntime(
      handler: (_) => Response.ok('unexpected'),
      client: client,
      endpoint: Uri.parse('http://runtime.invalid'),
      preflight: (_, _) => throw StateError('restricted-preflight-value'),
    );
    await runtime.runOnce();
    expect(posts, hasLength(1));
    expect(posts.single.url.path, endsWith('/error'));
    expect(posts.single.body, isNot(contains('restricted-preflight-value')));
    client.close();
  });
}
