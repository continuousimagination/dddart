import 'dart:async';
import 'dart:convert';

import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('timeout aborts pending headers and a later request recovers', () {
    fakeAsync((clock) {
      final pending = Completer<http.StreamedResponse>();
      var aborted = false;
      var calls = 0;
      final transport = _transport(
        MockClient.streaming((request, _) async {
          if (++calls == 1) {
            unawaited(
              (request as http.Abortable).abortTrigger!.then((_) {
                aborted = true;
                pending
                    .completeError(http.RequestAbortedException(request.url));
              }),
            );
            return pending.future;
          }
          return _emptyResponse();
        }),
      );
      Object? error;
      unawaited(
        transport.resolve([]).then<void>(
          (_) => fail('Expected cancellation'),
          onError: (Object value) {
            error = value;
          },
        ),
      );
      clock.elapse(const Duration(seconds: 3));
      expect(aborted, isTrue);
      expect(error, isA<http.RequestAbortedException>());
      List<EventWatchResult>? recovered;
      unawaited(transport.resolve([]).then((value) => recovered = value));
      clock.flushMicrotasks();
      expect(recovered, isEmpty);
      expect(calls, 2);
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });

  test('timeout cancels a body stalled after its response headers', () {
    fakeAsync((clock) {
      final body = StreamController<List<int>>();
      var aborted = false;
      final transport = _transport(
        MockClient.streaming((request, _) async {
          unawaited(
            (request as http.Abortable).abortTrigger!.then((_) {
              aborted = true;
              body.addError(http.RequestAbortedException(request.url));
              unawaited(body.close());
            }),
          );
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      Object? error;
      unawaited(
        transport.resolve([]).then<void>(
          (_) => fail('Expected cancellation'),
          onError: (Object value) {
            error = value;
          },
        ),
      );
      clock.elapse(const Duration(seconds: 3));
      expect(aborted, isTrue);
      expect(error, isNotNull);
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });

  test('close aborts an owned client and rejects its late response', () {
    fakeAsync((clock) {
      final httpClient = _LateClient();
      final transport = _transport(httpClient);
      Object? error;
      unawaited(
        transport.resolve([]).then<void>(
          (_) => fail('Late response was accepted'),
          onError: (Object value) {
            error = value;
          },
        ),
      );
      clock.flushMicrotasks();
      unawaited(transport.close());
      clock.flushMicrotasks();
      expect(httpClient.aborted, isTrue);
      expect(httpClient.closed, isTrue);
      httpClient.response.complete(_emptyResponse());
      clock.flushMicrotasks();
      expect(error, isA<EventPublicationException>());
    });
  });

  test('a longer configured timeout accepts a slow successful response', () {
    fakeAsync((clock) {
      final httpClient = _LateClient();
      final transport =
          _transport(httpClient, timeout: const Duration(seconds: 10));
      List<EventWatchResult>? result;
      unawaited(transport.resolve([]).then((value) => result = value));
      clock.elapse(const Duration(seconds: 5));
      expect(httpClient.aborted, isFalse);
      httpClient.response.complete(_emptyResponse());
      clock.flushMicrotasks();
      expect(result, isEmpty);
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });
}

HttpAggregateEventTransport _transport(
  http.Client client, {
  Duration timeout = const Duration(seconds: 2),
}) =>
    HttpAggregateEventTransport(
      baseUrl: Uri.parse('http://local/events'),
      wire: AggregateEventWire(IdentityCodecRegistry()),
      tokenProvider: () async => 'local-fixture',
      client: client,
      ownsClient: true,
      timeout: timeout,
    );
http.StreamedResponse _emptyResponse() =>
    http.StreamedResponse(Stream.value(utf8.encode('{"watches":[]}')), 200);

class _LateClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  bool aborted = false;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    unawaited(
      (request as http.Abortable).abortTrigger!.then((_) => aborted = true),
    );
    return response.future;
  }

  @override
  void close() => closed = true;
}
