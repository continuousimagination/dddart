import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_rest/credentials.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'event_fixture.dart';

void main() {
  test(
      'HTTP and native Lambda share signature, subject, issuer/audience and expiry checks',
      () async {
    final fixture = EventFixture();
    final verifier = JwtCredentialVerifier<Map<String, dynamic>>(
      secret: 'test-signing-secret',
      issuer: 'issuer',
      audience: 'app',
      parseClaimsFromJson: (json) => json,
    );
    Future<EventPrincipal<Map<String, dynamic>>?> authenticate(
      String token,
    ) async {
      final result = await verifier.verifyCredential(token);
      return result.isAuthenticated
          ? EventPrincipal(userId: result.userId!, claims: result.claims!)
          : null;
    }

    final handler = fixture.handlers(verifier: authenticate);
    final endpoints = AggregateEventHttpEndpoints(
      service: fixture.service,
      authenticate: authenticate,
    );
    final reference = fixture.reference();
    String signed(
      Map<String, dynamic> payload, {
      String secret = 'test-signing-secret',
      Duration expiry = const Duration(hours: 1),
    }) =>
        JWT(payload).sign(SecretKey(secret), expiresIn: expiry);
    final credentials = <(String, bool)>[
      (signed({'sub': 'alice', 'iss': 'issuer', 'aud': 'app'}), true),
      ('malformed.token', false),
      (signed({'sub': 'alice', 'iss': 'wrong', 'aud': 'app'}), false),
      (signed({'sub': 'alice', 'iss': 'issuer', 'aud': 'wrong'}), false),
      (
        signed(
          {'sub': 'alice', 'iss': 'issuer', 'aud': 'app'},
          secret: 'other-secret',
        ),
        false
      ),
      (
        signed(
          {'sub': 'alice', 'iss': 'issuer', 'aud': 'app'},
          expiry: const Duration(seconds: -1),
        ),
        false
      ),
      (signed({'sub': '', 'iss': 'issuer', 'aud': 'app'}), false),
    ];
    for (final (token, accepted) in credentials) {
      final native = await handler.authorize({
        'authorizationToken': token,
        'requestContext': {'operation': 'EVENT_CONNECT'},
      });
      final http = await endpoints.resolve(
        shelf.Request(
          'POST',
          Uri.parse('http://local/events/resolve'),
          headers: {'authorization': 'Bearer $token'},
          body: jsonEncode({
            'watches': [
              {
                'aggregate': reference.toJson(fixture.registry.identityCodecs),
              }
            ],
          }),
        ),
      );
      expect(native['isAuthorized'], accepted);
      expect(http.statusCode, accepted ? 200 : 401);
      expect(native['ttlOverride'], 0);
    }
  });

  test(
      'native subscription checks current mapping, policy, wildcard and identity',
      () async {
    final fixture = EventFixture();
    final handlers = fixture.handlers();
    final reference = fixture.reference();
    final channel = await fixture.channels.resolve(reference);
    Future<Map<String, dynamic>> identity(String user) async => {
          'handlerContext': (await handlers.authorize({
            'authorizationToken': 'valid:$user',
            'requestContext': {'operation': 'EVENT_CONNECT'},
          }))['handlerContext'],
        };
    expect(
      await handlers.onSubscribe(
        fixture.invocation('SUBSCRIBE', channel, await identity('alice')),
      ),
      isNull,
    );
    expect(
      await handlers.onSubscribe(
        fixture.invocation('SUBSCRIBE', channel, await identity('eve')),
      ),
      contains('error'),
    );
    final wildcard =
        fixture.invocation('SUBSCRIBE', channel, await identity('alice'));
    (wildcard['info']['channel'] as Map)['path'] = '/aggregates/*';
    expect(await handlers.onSubscribe(wildcard), contains('error'));
    final retired = channel;
    await fixture.channels.rotate(reference, UuidValue.generate());
    expect(
      await handlers.onSubscribe(
        fixture.invocation('SUBSCRIBE', retired, await identity('alice')),
      ),
      contains('error'),
    );
    final nativeClaims = {
      'sub': 'alice',
      'iss': 'issuer',
      'aud': 'app',
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
    };
    final current = await fixture.channels.resolve(reference);
    expect(
      await handlers.onSubscribe(
        fixture.invocation(
          'SUBSCRIBE',
          current,
          {'sub': 'alice', 'claims': nativeClaims},
        ),
      ),
      isNull,
    );
    for (final forged in [
      {'sub': 'eve', 'claims': nativeClaims},
      {
        'sub': 'alice',
        'claims': {...nativeClaims, 'iss': 'other'},
      },
      {
        'sub': 'alice',
        'claims': {...nativeClaims, 'exp': 1},
      },
    ]) {
      expect(
        await handlers
            .onSubscribe(fixture.invocation('SUBSCRIBE', current, forged)),
        contains('error'),
      );
    }
  });

  test(
      'partial publish validates reference and rights and awaits common handlers',
      () async {
    final fixture = EventFixture();
    final handlers = fixture.handlers();
    final reference = fixture.reference();
    final other = fixture.reference();
    final channel = await fixture.channels.resolve(reference);
    final authorized = await handlers.authorize({
      'authorizationToken': 'valid:alice',
      'requestContext': {'operation': 'EVENT_CONNECT'},
    });
    final identity = <String, dynamic>{
      'handlerContext': authorized['handlerContext'],
    };
    final envelope = fixture.envelope(reference);
    final result = await handlers.onPublish(
      fixture.invocation(
        'PUBLISH',
        channel,
        identity,
        events: [
          {
            'id': 'aws-0',
            'payload': {
              'kind': 'event',
              'envelope': envelope.toJson(fixture.wire.identities),
            },
          },
          {
            'id': 'aws-1',
            'payload': {
              'kind': 'event',
              'envelope':
                  fixture.envelope(other).toJson(fixture.wire.identities),
            },
          },
        ],
      ),
    );
    final output = result['events'] as List;
    expect(output[0]['id'], 'aws-0');
    expect(
      output[0]['payload']['record']['envelope']['event']['id'],
      envelope.id.uuid,
    );
    expect(output[1], {'id': 'aws-1', 'error': 'FORBIDDEN'});
    expect((await fixture.history.head(reference)).position, 1);
    expect((await fixture.history.head(other)).position, 0);
    expect(fixture.handled, 1);
    final bob = await handlers.authorize({
      'authorizationToken': 'valid:bob',
      'requestContext': {'operation': 'EVENT_CONNECT'},
    });
    final denied = await handlers.onPublish(
      fixture.invocation(
        'PUBLISH',
        channel,
        {
          'handlerContext': bob['handlerContext'],
        },
        events: [
          {
            'id': 'aws-bob',
            'payload': {
              'kind': 'event',
              'envelope':
                  fixture.envelope(reference).toJson(fixture.wire.identities),
            },
          }
        ],
      ),
    );
    expect((denied['events'] as List).single['error'], 'FORBIDDEN');
  });

  test('rotation emits only refresh to the retired channel and is idempotent',
      () async {
    final fixture = EventFixture();
    final handlers = fixture.handlers();
    final reference = fixture.reference();
    final previous = await fixture.channels.resolve(reference);
    final auth = await handlers.authorize({
      'authorizationToken': 'valid:alice',
      'requestContext': {'operation': 'EVENT_CONNECT'},
    });
    final identity = <String, dynamic>{
      'handlerContext': auth['handlerContext'],
    };
    final event = fixture.envelope(reference, label: 'removed');
    final payload = {
      'id': 'aws-event',
      'payload': {
        'kind': 'event',
        'envelope': event.toJson(fixture.wire.identities),
      },
    };
    fixture.policy.members[reference] = {'alice'};
    final response = await handlers.onPublish(
      fixture.invocation('PUBLISH', previous, identity, events: [payload]),
    );
    expect((response['events'] as List).single['payload'], {'kind': 'refresh'});
    final next = await fixture.channels.resolve(reference);
    expect(fixture.broadcasts.single.$1.id, next.id);
    expect(next.id, isNot(previous.id));
    await handlers.onPublish(
      fixture.invocation('PUBLISH', next, identity, events: [payload]),
    );
    expect((await fixture.channels.resolve(reference)).id, next.id);
    expect((await fixture.history.head(reference)).position, 1);
    final stale = await handlers.onPublish(
      fixture.invocation('PUBLISH', previous, identity, events: [payload]),
    );
    expect((stale['events'] as List).single['error'], 'RETRYABLE_CHANNEL');
  });

  test('only trusted IAM can relay accepted records or generic control hints',
      () async {
    final fixture = EventFixture();
    final handlers = fixture.handlers();
    final reference = fixture.reference();
    final channel = await fixture.channels.resolve(reference);
    final record = await fixture.history.append(fixture.envelope(reference));
    final payload = {
      'id': 'relay',
      'payload': {'kind': 'record', 'record': fixture.wire.record(record)},
    };
    final jwt = await handlers.authorize({
      'authorizationToken': 'valid:alice',
      'requestContext': {'operation': 'EVENT_CONNECT'},
    });
    final denied = await handlers.onPublish(
      fixture.invocation(
        'PUBLISH',
        channel,
        {'handlerContext': jwt['handlerContext']},
        events: [payload],
      ),
    );
    expect((denied['events'] as List).single['error'], 'FORBIDDEN');
    final iam = <String, dynamic>{
      'userArn': 'arn:aws:sts::123:assumed-role/backend/runtime',
    };
    final accepted = await handlers.onPublish(
      fixture.invocation('PUBLISH', channel, iam, events: [payload]),
    );
    expect((accepted['events'] as List).single['payload']['kind'], 'record');
    final leaked = await handlers.onPublish(
      fixture.invocation(
        'PUBLISH',
        channel,
        iam,
        events: [
          {
            'id': 'hint',
            'payload': {'kind': 'refresh', 'secretGameState': 'forbidden'},
          }
        ],
      ),
    );
    expect((leaked['events'] as List).single['error'], 'FORBIDDEN');
  });

  test(
      'optional HTTP bridge rejects forged callers, changed bodies and stale signatures',
      () async {
    final fixture = EventFixture();
    const secret = 'test-only-bridge-secret-more-than-32-characters';
    final now = DateTime.now().toUtc();
    final bridge = AppSyncHttpBridge(
      handlers: fixture.handlers(),
      secret: secret,
      clock: () => now,
    );
    final body = jsonEncode({
      'authorizationToken': 'valid:alice',
      'requestContext': {'operation': 'EVENT_CONNECT'},
    });
    final time = '${now.millisecondsSinceEpoch ~/ 1000}';
    final signature =
        AppSyncHttpBridge.signature(secret, '/native', time, body);
    Future<shelf.Response> call(
      String requestBody, {
      String? stamp,
      String? signed,
    }) =>
        bridge.handle(
          shelf.Request(
            'POST',
            Uri.parse('https://local/native'),
            body: requestBody,
            headers: {
              'x-dddart-appsync-time': stamp ?? time,
              'x-dddart-appsync-signature': signed ?? signature,
            },
          ),
        );
    expect((await call(body)).statusCode, 200);
    expect((await call('$body ')).statusCode, 403);
    expect((await call(body, signed: 'forged')).statusCode, 403);
    final staleTime =
        '${now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000}';
    expect(
      (await call(
        body,
        stamp: staleTime,
        signed: AppSyncHttpBridge.signature(
          secret,
          '/native',
          staleTime,
          body,
        ),
      ))
          .statusCode,
      403,
    );
  });
}
