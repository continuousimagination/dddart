import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:http/http.dart' as http;

/// Short-lived backend credentials, normally loaded from the Lambda environment.
/// Mobile clients do not need these; they use their existing JWT provider.
class AppSyncAwsCredentials {
  const AppSyncAwsCredentials({
    required this.accessKey,
    required this.secretKey,
    this.sessionToken,
  });
  final String accessKey;
  final String secretKey;
  final String? sessionToken;
}

/// SigV4 for the AppSync Events HTTP body, using fresh backend credentials.
class AppSyncIamAuthorization {
  AppSyncIamAuthorization({
    required this.region,
    required this.credentials,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final String region;
  final Future<AppSyncAwsCredentials> Function() credentials;
  final DateTime Function() _clock;
  Future<Map<String, String>> headers(Uri endpoint, String body) async {
    final keys = await credentials();
    final timestamp = _clock()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp('[-:]'), '')
        .split('.')
        .first;
    final dateTime = '${timestamp.substring(0, 15)}Z';
    final day = dateTime.substring(0, 8);
    final headers = <String, String>{
      'content-type': 'application/json',
      'host': endpoint.host,
      'x-amz-date': dateTime,
      if (keys.sessionToken != null) 'x-amz-security-token': keys.sessionToken!,
    };
    final names = headers.keys.toList()..sort();
    final signedHeaders = names.join(';');
    final canonicalHeaders =
        names.map((name) => '$name:${headers[name]!.trim()}\n').join();
    final canonical =
        'POST\n${endpoint.path}\n\n$canonicalHeaders\n$signedHeaders\n${sha256.convert(utf8.encode(body))}';
    final scope = '$day/$region/appsync/aws4_request';
    final toSign =
        'AWS4-HMAC-SHA256\n$dateTime\n$scope\n${sha256.convert(utf8.encode(canonical))}';
    List<int> sign(List<int> key, String text) =>
        Hmac(sha256, key).convert(utf8.encode(text)).bytes;
    final signingKey = sign(
      sign(
        sign(sign(utf8.encode('AWS4${keys.secretKey}'), day), region),
        'appsync',
      ),
      'aws4_request',
    );
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(toSign));
    headers['authorization'] =
        'AWS4-HMAC-SHA256 Credential=${keys.accessKey}/$scope, SignedHeaders=$signedHeaders, Signature=$signature';
    return headers;
  }
}

/// Server live relay/control sender; onPublish validates the trusted IAM identity.
class AppSyncHttpPublisher {
  AppSyncHttpPublisher({
    required this.endpoint,
    required this.namespace,
    required this.wire,
    required this.authorization,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    bool? ownsClient,
  })  : _client = client ?? http.Client(),
        _ownsClient = ownsClient ?? client == null {
    validateEventNamespace(namespace);
    if (endpoint.scheme != 'https' && endpoint.host != 'localhost') {
      throw ArgumentError('AppSync requires HTTPS');
    }
    if (endpoint.query.isNotEmpty) {
      throw ArgumentError('AppSync endpoint must not include a query');
    }
  }
  final Uri endpoint;
  final String namespace;
  final AggregateEventWire wire;

  /// May be AppSyncIamAuthorization.headers or an explicitly configured JWT signer.
  final Future<Map<String, String>> Function(Uri, String) authorization;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  Future<void> send(EventChannel channel, RecordedEvent record) =>
      _send(channel, {'kind': 'record', 'record': wire.record(record)});
  Future<void> refresh(EventChannel retired) =>
      _send(retired, {'kind': 'refresh'});
  Future<void> _send(EventChannel channel, Map<String, dynamic> payload) async {
    if (_closed) {
      throw const EventPublicationException('AppSync publisher closed');
    }
    final event = jsonEncode(payload);
    if (utf8.encode(event).length > 240 * 1024) {
      throw const EventPublicationException('AppSync event too large');
    }
    final body = jsonEncode({
      'channel': channel.path(namespace),
      'events': [event],
    });
    final response = await _client
        .post(
          endpoint,
          headers: {
            'content-type': 'application/json',
            ...await authorization(endpoint, body).timeout(timeout),
          },
          body: body,
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw EventPublicationException(
        'AppSync relay HTTP ${response.statusCode}',
        retryable: response.statusCode == 429 || response.statusCode >= 500,
      );
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if ((result['failed'] as List?)?.isNotEmpty ?? true) {
      throw const EventPublicationException(
        'AppSync relay rejected',
        retryable: true,
      );
    }
    if ((result['successful'] as List?)?.length != 1) {
      throw const EventPublicationException(
        'AppSync relay not acknowledged',
        retryable: true,
      );
    }
  }

  Future<void> close() async {
    _closed = true;
    if (_ownsClient) _client.close();
  }
}
