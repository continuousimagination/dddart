/// Runtime protocol tests use the real HTTP client boundary with no AWS calls.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dddart_rest/dddart_lambda.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Map<String, Object?> _event() => {
  'version': '2.0',
  'rawPath': '/probe',
  'rawQueryString': '',
  'headers': <String, String>{},
  'requestContext': {
    'http': {'method': 'GET'},
  },
  'isBase64Encoded': false,
};
Map<String, String> _headers() => {
  'lambda-runtime-aws-request-id': 'request-id',
  'lambda-runtime-deadline-ms': '1893456000000',
  'lambda-runtime-invocation-id': 'attempt-id',
};
void main() {
  final endpoint = Uri.parse('http://runtime.invalid');
  test('hung response/error/init delivery becomes terminal without retry', () {
    for (final scenario in ['response', 'error', 'init', 'deadline']) {
      fakeAsync((async) {
        final post = Completer<http.Response>();
        var gets = 0;
        var posts = 0;
        final client = MockClient((request) async {
          if (request.method == 'GET') {
            gets++;
            return http.Response(
              jsonEncode(_event()),
              200,
              headers: {
                ..._headers(),
                if (scenario == 'deadline')
                  'lambda-runtime-deadline-ms':
                      '${DateTime.utc(2025).millisecondsSinceEpoch}',
              },
            );
          }
          posts++;
          return post.future;
        });
        Object? failure;
        LambdaRuntime? runtime;
        Future<void> invoke() async {
          if (scenario == 'init') {
            await LambdaRuntime.initialize(
              initializeHandler: () => throw StateError('restricted-init'),
              client: client,
              endpoint: endpoint,
            );
          } else {
            runtime = LambdaRuntime(
              handler: (_) => scenario == 'error'
                  ? throw StateError('restricted-handler')
                  : Response.ok('ok'),
              client: client,
              endpoint: endpoint,
              clock: () => DateTime.utc(2026),
              deliveryTimeout: Duration(
                seconds: scenario == 'response' ? 2 : 1,
              ),
            );
            await runtime!.runOnce();
          }
        }

        invoke().then(
          (_) {},
          onError: (Object error) {
            failure = error;
          },
        );
        async.flushMicrotasks();
        expect(posts, 1);
        async.elapse(Duration(seconds: scenario == 'response' ? 2 : 1));
        async.flushMicrotasks();
        expect(failure, isA<StateError>(), reason: scenario);
        expect(failure.toString(), isNot(contains('restricted')));
        if (runtime != null) {
          runtime!.runOnce().then(
            (_) {},
            onError: (Object error) {
              failure = error;
            },
          );
          async.flushMicrotasks();
          expect(gets, 1);
        }
        post.complete(http.Response('', 202));
        async.flushMicrotasks();
        expect(posts, 1);
        client.close();
      });
    }
  });

  test('next polling installs no timeout timer', () {
    fakeAsync((async) {
      final next = Completer<http.Response>();
      final client = MockClient(
        (request) async =>
            request.method == 'GET' ? next.future : http.Response('', 202),
      );
      var done = false;
      final runtime = LambdaRuntime(
        handler: (_) => Response.ok('ok'),
        client: client,
        endpoint: endpoint,
        clock: () => DateTime.utc(2026),
      );
      runtime.runOnce().then((_) {
        done = true;
      });
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
      async.elapse(const Duration(hours: 1));
      expect(done, isFalse);
      next.complete(
        http.Response(jsonEncode(_event()), 200, headers: _headers()),
      );
      async.flushMicrotasks();
      expect(done, isTrue);
      client.close();
    });
  });
  test(
    'multiple invocations bind response to request id and echo distinct attempt id',
    () async {
      var gets = 0;
      var posts = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          gets++;
          expect(request.url.path, '/2018-06-01/runtime/invocation/next');
          return http.Response(jsonEncode(_event()), 200, headers: _headers());
        }
        posts++;
        expect(
          request.url.path,
          '/2018-06-01/runtime/invocation/request-id/response',
        );
        expect(request.headers['lambda-runtime-invocation-id'], 'attempt-id');
        expect((jsonDecode(request.body) as Map)['statusCode'], 200);
        return http.Response('', 202);
      });
      final runtime = LambdaRuntime(
        handler: (_) => Response.ok('ok'),
        client: client,
        endpoint: endpoint,
        clock: () => DateTime.utc(2026),
      );
      await runtime.runOnce();
      await runtime.runOnce();
      expect(gets, 2);
      expect(posts, 2);
      client.close();
    },
  );
  test('handler failure posts one safe invocation error', () async {
    final posted = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(_event()), 200, headers: _headers());
      }
      posted.add(request);
      return http.Response('', 202);
    });
    final runtime = LambdaRuntime(
      handler: (_) => throw StateError('restricted-handler-value'),
      client: client,
      endpoint: endpoint,
      clock: () => DateTime.utc(2026),
    );
    await runtime.runOnce();
    expect(posted, hasLength(1));
    expect(posted.single.url.path, endsWith('/request-id/error'));
    expect(posted.single.body, isNot(contains('restricted-handler-value')));
    client.close();
  });
  test('expired invocation never invokes handler', () async {
    var calls = 0;
    final client = MockClient(
      (request) async => request.method == 'GET'
          ? http.Response(jsonEncode(_event()), 200, headers: _headers())
          : http.Response('', 202),
    );
    await expectLater(
      LambdaRuntime(
        handler: (_) {
          calls++;
          return Response.ok('no');
        },
        client: client,
        endpoint: endpoint,
        clock: () => DateTime.utc(2031),
      ).runOnce(),
      throwsStateError,
    );
    expect(calls, 0);
    client.close();
  });
  test(
    'uncertain response posting is terminal and never followed by error/retry',
    () async {
      var sends = 0;
      final client = MockClient((request) async {
        sends++;
        if (request.method == 'GET') {
          return http.Response(jsonEncode(_event()), 200, headers: _headers());
        }
        throw http.ClientException('restricted-delivery-value');
      });
      final runtime = LambdaRuntime(
        handler: (_) => Response.ok('ok'),
        client: client,
        endpoint: endpoint,
        clock: () => DateTime.utc(2026),
      );
      await expectLater(runtime.runOnce(), throwsStateError);
      expect(sends, 2);
      await expectLater(runtime.runOnce(), throwsStateError);
      expect(sends, 2);
      client.close();
    },
  );
  test(
    'initialization failure posts safe init/error and cannot create runtime',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/2018-06-01/runtime/init/error');
        expect(request.body, isNot(contains('restricted-init-value')));
        return http.Response('', 202);
      });
      await expectLater(
        LambdaRuntime.initialize(
          initializeHandler: () => throw StateError('restricted-init-value'),
          client: client,
          endpoint: endpoint,
        ),
        throwsStateError,
      );
      expect(calls, 1);
      client.close();
    },
  );
  test('next protocol failures are terminal and do not call handler', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('restricted-runtime-value', 500);
    });
    final runtime = LambdaRuntime(
      handler: (_) => Response.ok('no'),
      client: client,
      endpoint: endpoint,
    );
    await expectLater(runtime.runOnce(), throwsStateError);
    await expectLater(runtime.runOnce(), throwsStateError);
    expect(calls, 1);
    client.close();
  });
  test(
    'deadline expiry is terminal and late handler completion cannot repost',
    () {
      fakeAsync((async) {
        final handler = Completer<Response>();
        final now = DateTime.utc(2026);
        final sent = <http.Request>[];
        final client = MockClient((request) async {
          sent.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(_event()),
              200,
              headers: {
                ..._headers(),
                'lambda-runtime-deadline-ms':
                    '${now.add(const Duration(seconds: 1)).millisecondsSinceEpoch}',
              },
            );
          }
          return http.Response('', 202);
        });
        final runtime = LambdaRuntime(
          handler: (_) => handler.future,
          client: client,
          endpoint: endpoint,
          clock: () => now,
        );
        Object? failure;
        runtime.runOnce().then(
          (_) {},
          onError: (Object error) {
            failure = error;
          },
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(failure, isA<StateError>());
        expect(sent, hasLength(2));
        expect(sent.last.url.path, endsWith('/error'));
        runtime.runOnce().then(
          (_) {},
          onError: (Object error) {
            failure = error;
          },
        );
        async.flushMicrotasks();
        expect(sent, hasLength(2));
        handler.complete(Response.ok('late'));
        async.flushMicrotasks();
        expect(sent, hasLength(2));
        client.close();
      });
    },
  );
  test(
    'an early application I/O TimeoutException is not the runtime deadline',
    () async {
      var next = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          next++;
          return http.Response(jsonEncode(_event()), 200, headers: _headers());
        }
        return http.Response('', 202);
      });
      final runtime = LambdaRuntime(
        handler: (_) => throw TimeoutException('application I/O'),
        client: client,
        endpoint: endpoint,
        clock: () => DateTime.utc(2026),
      );
      await runtime.runOnce();
      await runtime.runOnce();
      expect(next, 2);
      client.close();
    },
  );
  test(
    'rejected response or error POST is terminal without another delivery',
    () async {
      for (final failHandler in [false, true]) {
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(_event()),
              200,
              headers: _headers(),
            );
          }
          expect(
            request.url.path,
            endsWith(failHandler ? '/error' : '/response'),
          );
          return http.Response('restricted-post-response', 500);
        });
        final runtime = LambdaRuntime(
          handler: (_) {
            if (failHandler) throw StateError('synthetic');
            return Response.ok('ok');
          },
          client: client,
          endpoint: endpoint,
          clock: () => DateTime.utc(2026),
        );
        await expectLater(runtime.runOnce(), throwsStateError);
        await expectLater(runtime.runOnce(), throwsStateError);
        expect(calls, 2);
        client.close();
      }
    },
  );
}
