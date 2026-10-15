import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_bus_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('request credentials', () {
    for (final staticToken in [null, 'constructor-token']) {
      test('provider overrides $staticToken for GET and POST after rotation',
          () {
        fakeAsync((clock) {
          var token = 'first';
          final headers = <String, List<String?>>{'GET': [], 'POST': []};
          final client = EventBusClient(
            localEventBus: EventBus(),
            serverUrl: 'https://example.test',
            eventRegistry: {},
            autoForward: true,
            pollingInterval: const Duration(seconds: 1),
            authToken: staticToken,
            authTokenProvider: () async => token,
            httpClient: MockClient((request) async {
              headers[request.method]!.add(request.headers['authorization']);
              return http.Response('[]', request.method == 'GET' ? 200 : 201);
            }),
          );
          client.publish(_Event('first'));
          clock.elapse(const Duration(seconds: 1));
          token = 'rotated';
          client.publish(_Event('second'));
          clock.elapse(const Duration(seconds: 1));
          for (final values in headers.values) {
            expect(values, ['Bearer first', 'Bearer rotated']);
          }
          unawaited(client.close());
          clock.flushMicrotasks();
        });
      });
    }

    test('static credentials still authenticate both request types', () {
      fakeAsync((clock) {
        final headers = <String, String?>{};
        final client = EventBusClient(
          localEventBus: EventBus(),
          serverUrl: 'https://example.test',
          eventRegistry: {},
          autoForward: true,
          authToken: 'static',
          pollingInterval: const Duration(seconds: 1),
          httpClient: MockClient((request) async {
            headers[request.method] = request.headers['authorization'];
            return http.Response('[]', request.method == 'GET' ? 200 : 201);
          }),
        );
        client.publish(_Event('local'));
        clock.elapse(const Duration(seconds: 1));
        expect(headers, {'GET': 'Bearer static', 'POST': 'Bearer static'});
        unawaited(client.close());
        clock.flushMicrotasks();
      });
    });

    test('provider returning null does not reuse a stale static token', () {
      fakeAsync((clock) {
        final headers = <String, String?>{};
        final client = EventBusClient(
          localEventBus: EventBus(),
          serverUrl: 'https://example.test',
          eventRegistry: {},
          autoForward: true,
          authToken: 'stale',
          authTokenProvider: () async => null,
          pollingInterval: const Duration(seconds: 1),
          httpClient: MockClient((request) async {
            headers[request.method] = request.headers['authorization'];
            return http.Response('[]', request.method == 'GET' ? 200 : 201);
          }),
        );
        client.publish(_Event('local'));
        clock.elapse(const Duration(seconds: 1));
        expect(headers, {'GET': null, 'POST': null});
        unawaited(client.close());
        clock.flushMicrotasks();
      });
    });
  });

  test('timeout retains ownership until cancellation settles, then recovers',
      () {
    fakeAsync((clock) {
      final transport = _ControlledClient();
      final client = _pollingClient(transport);
      clock.elapse(const Duration(seconds: 5));
      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.abortRequested, isTrue);
      expect(transport.active, 1);

      transport.calls.single.cancel();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      expect(transport.calls, hasLength(2));
      transport.calls.last.complete([]);
      clock.flushMicrotasks();
      expect(transport.active, 0);
      expect(transport.maxActive, 1);
      unawaited(client.close());
      clock.flushMicrotasks();
      expect(transport.closed, isTrue);
      clock.elapse(const Duration(seconds: 10));
      expect(transport.calls, hasLength(2));
    });
  });

  test('a response slower than the default timeout is ignored without overlap',
      () {
    fakeAsync((clock) {
      final transport = _ControlledClient();
      final received = <String>[];
      final client = _pollingClient(transport, received: received);
      clock.elapse(const Duration(seconds: 5));
      expect(transport.calls, hasLength(1));
      transport.calls.single.complete([_stored('late', 1)]);
      clock.flushMicrotasks();
      expect(received, isEmpty);
      clock.elapse(const Duration(seconds: 1));
      transport.calls.last.complete([_stored('recovered', 1)]);
      clock.flushMicrotasks();
      expect(received, ['recovered']);
      expect(transport.maxActive, 1);
      unawaited(client.close());
      clock.flushMicrotasks();
    });
  });

  test('a longer configured timeout accepts a slow successful response', () {
    fakeAsync((clock) {
      final transport = _ControlledClient();
      final received = <String>[];
      final client = _pollingClient(
        transport,
        received: received,
        requestTimeout: const Duration(seconds: 10),
      );
      clock.elapse(const Duration(seconds: 5));
      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.abortRequested, isFalse);
      transport.calls.single.complete([_stored('slow', 1)]);
      clock.flushMicrotasks();
      expect(received, ['slow']);
      unawaited(client.close());
      clock.flushMicrotasks();
    });
  });

  test('close aborts an active request and ignores its late response', () {
    fakeAsync((clock) {
      final transport = _ControlledClient();
      final received = <String>[];
      final client = _pollingClient(transport, received: received);
      clock.elapse(const Duration(seconds: 1));
      unawaited(client.close());
      clock.flushMicrotasks();
      expect(transport.calls.single.abortRequested, isTrue);
      expect(transport.closed, isTrue);
      transport.calls.single.complete([_stored('after-close', 1)]);
      clock.elapse(const Duration(seconds: 10));
      expect(received, isEmpty);
      expect(transport.calls, hasLength(1));
    });
  });

  test('timeout also aborts a response stalled after its headers', () {
    fakeAsync((clock) {
      final body = StreamController<List<int>>();
      var calls = 0;
      var aborted = false;
      final transport = MockClient.streaming((request, _) async {
        calls++;
        if (calls == 1) {
          unawaited(
            (request as http.Abortable).abortTrigger!.then((_) {
              aborted = true;
              body.addError(http.RequestAbortedException(request.url));
              unawaited(body.close());
            }),
          );
          return http.StreamedResponse(body.stream, 200);
        }
        return http.StreamedResponse(Stream.value(utf8.encode('[]')), 200);
      });
      final client = _pollingClient(transport);
      clock.elapse(const Duration(seconds: 4));
      expect(aborted, isTrue);
      expect(calls, 2);
      unawaited(client.close());
      clock.flushMicrotasks();
    });
  });

  test('unordered inclusive batches deliver in time order and deduplicate IDs',
      () {
    fakeAsync((clock) {
      final transport = _ControlledClient();
      final received = <String>[];
      final client = _pollingClient(transport, received: received);
      clock.elapse(const Duration(seconds: 1));
      transport.calls.last.complete([
        _stored('later', 2),
        _stored('earlier', 1),
        _stored('tie', 2),
      ]);
      clock.flushMicrotasks();
      expect(received.first, 'earlier');
      expect(received.skip(1), unorderedEquals(['later', 'tie']));
      clock.elapse(const Duration(seconds: 1));
      expect(
        transport.calls.last.request.url.queryParameters['since'],
        _epoch.add(const Duration(seconds: 2)).toIso8601String(),
      );
      transport.calls.last.complete([
        _stored('tie', 2),
        _stored('later', 2),
        _stored('new-tie', 2),
      ]);
      clock.flushMicrotasks();
      expect(received.last, 'new-tie');
      expect(received, hasLength(4));
      clock.elapse(const Duration(seconds: 1));
      transport.calls.last.complete([
        _stored('earlier', 1),
        _stored('later', 2),
        _stored('tie', 2),
        _stored('new-tie', 2),
      ]);
      clock.flushMicrotasks();
      expect(received, hasLength(4));
      unawaited(client.close());
      clock.flushMicrotasks();
    });
  });
}

final _epoch = DateTime.utc(2026);

EventBusClient _pollingClient(
  http.Client transport, {
  List<String>? received,
  Duration requestTimeout = const Duration(seconds: 2),
}) {
  final bus = EventBus();
  bus.on<_Event>().listen((event) => received?.add(event.label));
  return EventBusClient(
    localEventBus: bus,
    serverUrl: 'https://example.test',
    eventRegistry: {'TestEvent': (json) => _Event(json['label'] as String)},
    initialTimestamp: _epoch,
    pollingInterval: const Duration(seconds: 1),
    requestTimeout: requestTimeout,
    httpClient: transport,
  );
}

Map<String, dynamic> _stored(String id, int seconds) => {
      'id': id,
      'createdAt': _epoch.add(Duration(seconds: seconds)).toIso8601String(),
      'eventType': 'TestEvent',
      'eventJson': jsonEncode({'label': id}),
    };

class _Event extends DomainEvent {
  _Event(this.label) : super(aggregateId: UuidValue.generate());
  final String label;
}

class _ControlledClient extends http.BaseClient {
  final calls = <_Call>[];
  int active = 0;
  int maxActive = 0;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final call = _Call(request);
    calls.add(call);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await call.response.future;
    } finally {
      active--;
    }
  }

  @override
  void close() => closed = true;
}

class _Call {
  _Call(this.request) {
    if (request is http.Abortable) {
      unawaited(
        (request as http.Abortable).abortTrigger?.then((_) {
          abortRequested = true;
        }),
      );
    }
  }
  final http.BaseRequest request;
  final response = Completer<http.StreamedResponse>();
  bool abortRequested = false;

  void cancel() => response.completeError(http.RequestAbortedException());

  void complete(List<Map<String, dynamic>> events) => response.complete(
        http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(events))),
          200,
        ),
      );
}
