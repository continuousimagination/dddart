@Tags(['aws'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _requiredEnvironmentVariables = <String>[
  'DDDART_APPSYNC_REALTIME_URL',
  'DDDART_APPSYNC_HTTP_ENDPOINT',
  'DDDART_APPSYNC_JWT_A',
  'DDDART_APPSYNC_USER_SUB_A',
];

void main() {
  final config = _AwsSmokeConfig.fromEnvironment(Platform.environment);
  if (config == null) {
    test(
      'skips until AWS AppSync Events smoke environment is configured',
      () {},
      skip: 'Missing one or more required environment variables: '
          '${_requiredEnvironmentVariables.join(', ')}',
    );
    return;
  }

  group('AWS AppSync Events smoke', () {
    late http.Client httpClient;
    late EventBus eventBus;

    setUp(() {
      httpClient = http.Client();
      eventBus = EventBus();
    });

    tearDown(() async {
      httpClient.close();
      await eventBus.close();
    });

    test(
      'subscribes to own inbox channel and receives a StoredEvent',
      () async {
        var catchUpRequests = 0;
        final transport = AppSyncEventsTransport(
          realtimeEndpoint: config.realtimeEndpoint,
          channel: config.ownChannel,
          authorization: AppSyncEventsAuthorization.cognitoJwt(
            host: config.authHost,
            jwt: config.jwtA,
          ),
          subscriptionId: 'dddart-aws-smoke-own',
          connectionAckTimeout: const Duration(seconds: 20),
          subscribeAckTimeout: const Duration(seconds: 20),
          onCatchUpNeeded: () {
            catchUpRequests += 1;
          },
        );
        final bridge = DistributedEventBusBridge(
          localEventBus: eventBus,
          transport: transport,
          storedEventDecoder: _decodeAwsSmokeEvent,
        );
        final received = eventBus.on<_AwsSmokeEvent>().first;

        await transport.connect();
        bridge.start();

        final event = _AwsSmokeEvent(
          aggregateId: UuidValue.generate(),
          eventId: UuidValue.generate(),
          occurredAt: DateTime.now().toUtc(),
          message: 'dddart AppSync Events smoke',
          context: {'userId': config.userSubA},
        );
        final storedEvent = StoredEvent.fromDomainEvent(event);

        await _publishStoredEvent(
          httpClient: httpClient,
          config: config,
          channel: config.ownChannel,
          storedEvent: storedEvent,
        );

        final delivered = await received.timeout(const Duration(seconds: 20));
        expect(delivered.eventId, equals(event.eventId));
        expect(delivered.aggregateId, equals(event.aggregateId));
        expect(delivered.message, equals(event.message));
        expect(catchUpRequests, greaterThanOrEqualTo(1));

        await bridge.close();
        await transport.close();
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'denies cross-user subscription when a second user is configured',
      () async {
        if (!config.hasSecondUser) {
          markTestSkipped(
            'DDDART_APPSYNC_JWT_B and DDDART_APPSYNC_USER_SUB_B are optional; '
            'set both to validate cross-user subscription denial.',
          );
          return;
        }

        final allowedTransport = AppSyncEventsTransport(
          realtimeEndpoint: config.realtimeEndpoint,
          channel: config.secondUserChannel,
          authorization: AppSyncEventsAuthorization.cognitoJwt(
            host: config.authHost,
            jwt: config.jwtB!,
          ),
          subscriptionId: 'dddart-aws-smoke-user-b-own',
          connectionAckTimeout: const Duration(seconds: 20),
          subscribeAckTimeout: const Duration(seconds: 20),
        );
        try {
          await allowedTransport.connect();
        } finally {
          await allowedTransport.close();
        }

        final deniedTransport = AppSyncEventsTransport(
          realtimeEndpoint: config.realtimeEndpoint,
          channel: config.secondUserChannel,
          authorization: AppSyncEventsAuthorization.cognitoJwt(
            host: config.authHost,
            jwt: config.jwtA,
          ),
          subscriptionId: 'dddart-aws-smoke-cross-user',
          connectionAckTimeout: const Duration(seconds: 20),
          subscribeAckTimeout: const Duration(seconds: 20),
        );

        Object? denialError;
        try {
          await deniedTransport.connect();
        } catch (error) {
          denialError = error;
        } finally {
          await deniedTransport.close();
        }

        expect(
          denialError,
          isNotNull,
          reason: 'User A was able to subscribe to user B channel '
              '${config.secondUserChannel}; AppSync authorization should deny '
              'cross-user inbox subscriptions.',
        );
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  });
}

Future<void> _publishStoredEvent({
  required http.Client httpClient,
  required _AwsSmokeConfig config,
  required String channel,
  required StoredEvent storedEvent,
}) async {
  final response = await httpClient.post(
    config.publishEndpoint,
    headers: config.publishHeaders,
    body: jsonEncode({
      'channel': channel,
      'events': [jsonEncode(storedEvent.toJson())],
    }),
  );

  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: 'AppSync Events HTTP publish returned ${response.statusCode}.',
  );
}

DomainEvent? _decodeAwsSmokeEvent(StoredEvent storedEvent) {
  if (storedEvent.eventType != '_AwsSmokeEvent') {
    return null;
  }

  return _AwsSmokeEvent.fromJson(
    jsonDecode(storedEvent.eventJson) as Map<String, Object?>,
  );
}

class _AwsSmokeConfig {
  const _AwsSmokeConfig({
    required this.realtimeEndpoint,
    required this.publishEndpoint,
    required this.authHost,
    required this.jwtA,
    required this.userSubA,
    required this.publishHeaders,
    this.jwtB,
    this.userSubB,
  });

  static _AwsSmokeConfig? fromEnvironment(Map<String, String> environment) {
    for (final name in _requiredEnvironmentVariables) {
      if ((environment[name] ?? '').trim().isEmpty) {
        return null;
      }
    }

    final publishEndpoint = _parsePublishEndpoint(
      environment['DDDART_APPSYNC_HTTP_ENDPOINT']!,
    );
    final authHost = (environment['DDDART_APPSYNC_AUTH_HOST'] ?? '').trim();
    final publishApiKey =
        (environment['DDDART_APPSYNC_PUBLISH_API_KEY'] ?? '').trim();
    final publishJwt = (environment['DDDART_APPSYNC_PUBLISH_JWT'] ?? '').trim();
    final jwtA = environment['DDDART_APPSYNC_JWT_A']!.trim();

    return _AwsSmokeConfig(
      realtimeEndpoint: Uri.parse(
        environment['DDDART_APPSYNC_REALTIME_URL']!.trim(),
      ),
      publishEndpoint: publishEndpoint,
      authHost: authHost.isEmpty ? publishEndpoint.host : authHost,
      jwtA: jwtA,
      userSubA: environment['DDDART_APPSYNC_USER_SUB_A']!.trim(),
      jwtB: _emptyToNull(environment['DDDART_APPSYNC_JWT_B']),
      userSubB: _emptyToNull(environment['DDDART_APPSYNC_USER_SUB_B']),
      publishHeaders: {
        'content-type': 'application/json',
        if (publishApiKey.isNotEmpty) 'x-api-key': publishApiKey,
        if (publishApiKey.isEmpty)
          'Authorization': 'Bearer ${publishJwt.isEmpty ? jwtA : publishJwt}',
      },
    );
  }

  final Uri realtimeEndpoint;
  final Uri publishEndpoint;
  final String authHost;
  final String jwtA;
  final String userSubA;
  final String? jwtB;
  final String? userSubB;
  final Map<String, String> publishHeaders;

  String get ownChannel => '/users/$userSubA/events';

  String get secondUserChannel => '/users/$userSubB/events';

  bool get hasSecondUser => jwtB != null && userSubB != null;

  static Uri _parsePublishEndpoint(String rawValue) {
    final trimmed = rawValue.trim();
    final value =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.parse(value);
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.replace(path: '/event');
    }
    return uri;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

Map<String, Object?> _decodeContext(Object? value) {
  if (value == null) {
    return const {};
  }
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) {
      if (key is! String) {
        throw FormatException('Expected context key to be a string, got $key');
      }
      return MapEntry(key, value);
    });
  }
  throw FormatException('Expected context to be an object, got $value');
}

class _AwsSmokeEvent extends DomainEvent {
  _AwsSmokeEvent({
    required super.aggregateId,
    required this.message,
    super.eventId,
    super.occurredAt,
    super.context = const {},
  });

  factory _AwsSmokeEvent.fromJson(Map<String, Object?> json) {
    return _AwsSmokeEvent(
      aggregateId: UuidValue.fromString(json['aggregateId']! as String),
      eventId: UuidValue.fromString(json['eventId']! as String),
      occurredAt: DateTime.parse(json['occurredAt']! as String),
      context: _decodeContext(json['context']),
      message: json['message']! as String,
    );
  }

  final String message;

  Map<String, Object?> toJson() {
    return {
      'eventId': eventId.toString(),
      'occurredAt': occurredAt.toIso8601String(),
      'aggregateId': aggregateId.toString(),
      'context': context,
      'message': message,
    };
  }
}
