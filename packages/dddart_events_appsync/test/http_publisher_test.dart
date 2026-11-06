import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'event_fixture.dart';

void main() {
  test('backend signing uses fresh short-lived credentials and the exact body',
      () async {
    var access = 'access';
    final auth = AppSyncIamAuthorization(
      region: 'us-east-1',
      clock: () => DateTime.utc(2026, 11, 6),
      credentials: () async => AppSyncAwsCredentials(
        accessKey: access,
        secretKey: 'secret',
        sessionToken: 'session',
      ),
    );
    final first = await auth.headers(
      Uri.parse('https://api.example/event'),
      '{"hello":"world"}',
    );
    expect(first['x-amz-date'], '20261106T000000Z');
    expect(first['x-amz-security-token'], 'session');
    expect(
      first['authorization'],
      contains('Credential=access/20261106/us-east-1/appsync/aws4_request'),
    );
    expect(
      first['authorization'],
      contains(
        'SignedHeaders=content-type;host;x-amz-date;x-amz-security-token',
      ),
    );
    expect(
      (await auth.headers(
        Uri.parse('https://api.example/event'),
        '{"hello":"different"}',
      ))['authorization'],
      isNot(first['authorization']),
    );
    access = 'rotated';
    expect(
      (await auth.headers(
        Uri.parse('https://api.example/event'),
        '{"hello":"world"}',
      ))['authorization'],
      contains('Credential=rotated/'),
    );
  });

  test('HTTP relay uses stringified AWS events and rejects partial failures',
      () async {
    final fixture = EventFixture();
    final reference = fixture.reference();
    final channel = await fixture.channels.resolve(reference);
    final record = await fixture.history.append(fixture.envelope(reference));
    var fail = false;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['channel'], channel.path('aggregates'));
      final payload =
          jsonDecode((body['events'] as List).single as String) as Map;
      expect(payload['kind'], anyOf('record', 'refresh'));
      return http.Response(
        jsonEncode({
          'successful': fail
              ? <Object?>[]
              : [
                  {'identifier': 'accepted', 'index': 0},
                ],
          'failed': fail
              ? [
                  {'index': 0, 'message': 'RETRYABLE'},
                ]
              : <Object?>[],
        }),
        200,
      );
    });
    final publisher = AppSyncHttpPublisher(
      endpoint: Uri.parse('https://api.example/event'),
      namespace: 'aggregates',
      wire: fixture.wire,
      authorization: (uri, body) async => {'Authorization': 'backend'},
      client: client,
    );
    addTearDown(() async {
      await publisher.close();
      client.close();
    });
    await publisher.send(channel, record);
    await publisher.refresh(channel);
    fail = true;
    await expectLater(
      publisher.send(channel, record),
      throwsA(isA<EventPublicationException>()),
    );
    await publisher.close();
    await expectLater(
      publisher.refresh(channel),
      throwsA(isA<EventPublicationException>()),
    );
    expect(record.envelope.id, isA<UuidValue>());
  });
}
