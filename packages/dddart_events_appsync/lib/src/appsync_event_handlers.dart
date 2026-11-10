import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Native AppSync Lambda authorizer and DIRECT subscribe/publish invocation API.
///
/// These inputs are trusted AWS invocation contexts, never public HTTP bodies.
/// Use AppSyncHttpBridge for an explicitly authenticated HTTP integration.
class AppSyncEventHandlers<C> {
  AppSyncEventHandlers({
    required this.service,
    required this.namespace,
    required this.authenticate,
    required this.encodeClaims,
    required this.decodeClaims,
    required this.trustedRelay,
    this.nativeIssuer,
    this.nativeAudience,
  });
  final AggregateEventService<C> service;
  final String namespace;
  final EventAuthenticator<C> authenticate;
  final Map<String, dynamic> Function(C) encodeClaims;
  final C Function(Map<String, dynamic>) decodeClaims;

  /// Verifies the AWS-populated IAM userArn against the application's backend role.
  /// Never decide this from a client-supplied header or JWT claim.
  final bool Function(Map<String, dynamic> identity) trustedRelay;
  final String? nativeIssuer;
  final String? nativeAudience;

  Future<dynamic> handle(Map<String, dynamic> invocation) async {
    if (invocation.containsKey('authorizationToken')) {
      return authorize(invocation);
    }
    final info = Map<String, dynamic>.from(invocation['info'] as Map? ?? {});
    if (info['operation'] == 'SUBSCRIBE') return onSubscribe(invocation);
    if (info['operation'] == 'PUBLISH') return onPublish(invocation);
    return {'error': 'Unsupported invocation'};
  }

  /// AWS_LAMBDA response; policy results are deliberately not cached.
  Future<Map<String, dynamic>> authorize(
    Map<String, dynamic> invocation,
  ) async {
    try {
      final context =
          Map<String, dynamic>.from(invocation['requestContext'] as Map);
      var token = invocation['authorizationToken'] as String;
      if (token.startsWith('Bearer ')) token = token.substring(7);
      final principal = await authenticate(token);
      if (principal == null) return {'isAuthorized': false, 'ttlOverride': 0};
      final operation = context['operation'];
      if (operation == 'EVENT_SUBSCRIBE') {
        final channel = await service.channels
            .find(parseEventChannel(context['channel'] as String, namespace));
        if (channel == null) throw const EventAccessDenied();
        await service.resolve(principal, channel.aggregate);
      } else if (operation == 'EVENT_PUBLISH') {
        // Per-event authorization runs in onPublish, where payload is available.
        parseEventChannel(context['channel'] as String, namespace);
      } else if (operation != 'EVENT_CONNECT') {
        throw const EventAccessDenied();
      }
      return {
        'isAuthorized': true,
        'ttlOverride': 0,
        'handlerContext': {
          'dddartPrincipal': jsonEncode({
            'userId': principal.userId,
            'claims': encodeClaims(principal.claims),
          }),
        },
      };
    } catch (error, stack) {
      service.logger.fine('AppSync authorization denied', error, stack);
      return {'isAuthorized': false, 'ttlOverride': 0};
    }
  }

  EventPrincipal<C> _principal(Map<String, dynamic> identity) {
    final handler = identity['handlerContext'];
    if (handler is Map && handler['dddartPrincipal'] is String) {
      final value = jsonDecode(handler['dddartPrincipal'] as String)
          as Map<String, dynamic>;
      return EventPrincipal(
        userId: value['userId'] as String,
        claims: decodeClaims(Map<String, dynamic>.from(value['claims'] as Map)),
      );
    }
    // Cognito/OIDC signature, expiry and provider constraints were verified by
    // AppSync. Consume only its native identity, never forwarded request claims.
    final claims = Map<String, dynamic>.from(identity['claims'] as Map);
    final subject = claims['sub'] as String;
    if (subject.isEmpty ||
        (identity['sub'] != null && identity['sub'] != subject)) {
      throw const EventAccessDenied();
    }
    if (nativeIssuer != null && claims['iss'] != nativeIssuer) {
      throw const EventAccessDenied();
    }
    final audience = claims['aud'];
    if (nativeAudience != null &&
        audience != nativeAudience &&
        !(audience is List && audience.contains(nativeAudience))) {
      throw const EventAccessDenied();
    }
    final expiry = claims['exp'];
    if (expiry is! num ||
        expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      throw const EventAccessDenied();
    }
    return EventPrincipal(userId: subject, claims: decodeClaims(claims));
  }

  String _path(Map<String, dynamic> invocation) =>
      ((invocation['info'] as Map)['channel'] as Map)['path'] as String;

  /// DIRECT subscription response is null on success, not isAuthorized.
  Future<Map<String, dynamic>?> onSubscribe(
    Map<String, dynamic> invocation,
  ) async {
    try {
      final channel = await service.channels
          .find(parseEventChannel(_path(invocation), namespace));
      if (channel == null) throw const EventAccessDenied();
      await service.resolve(
        _principal(Map<String, dynamic>.from(invocation['identity'] as Map)),
        channel.aggregate,
      );
      return null;
    } catch (error, stack) {
      service.logger.fine('AppSync subscription denied', error, stack);
      return {'error': 'Forbidden'};
    }
  }

  /// DIRECT per-item response preserves AppSync's incoming id values.
  Future<Map<String, dynamic>> onPublish(
    Map<String, dynamic> invocation,
  ) async {
    final output = <Map<String, dynamic>>[];
    try {
      final id = parseEventChannel(_path(invocation), namespace);
      final identity = Map<String, dynamic>.from(invocation['identity'] as Map);
      final relay = trustedRelay(identity);
      final events = invocation['events'] as List;
      if (events.length > 5) throw const FormatException('Too many events');
      final wire = AggregateEventWire(service.registry.identityCodecs);
      for (final raw in events) {
        final item = Map<String, dynamic>.from(raw as Map);
        final itemId = item['id'] as String;
        try {
          final rawPayload = item['payload'];
          final payload = rawPayload is String
              ? jsonDecode(rawPayload) as Map<String, dynamic>
              : Map<String, dynamic>.from(rawPayload as Map);
          if (utf8.encode(jsonEncode(payload)).length > 240 * 1024) {
            throw const FormatException('Payload too large');
          }
          if (payload['kind'] == 'refresh') {
            if (!relay || payload.length != 1) throw const EventAccessDenied();
            output.add({
              'id': itemId,
              'payload': {'kind': 'refresh'},
            });
            continue;
          }
          final channel = await service.channels.find(id);
          if (channel == null) {
            output.add({'id': itemId, 'error': 'RETRYABLE_CHANNEL'});
            continue;
          }
          if (payload['kind'] == 'record') {
            if (!relay) throw const EventAccessDenied();
            final record = wire.parseRecord(
              Map<String, dynamic>.from(payload['record'] as Map),
            );
            final accepted = await service.history.getById(record.envelope.id);
            if (record.envelope.aggregate != channel.aggregate ||
                accepted.canonicalJson(wire.identities) !=
                    record.envelope.canonicalJson(wire.identities)) {
              throw const EventAccessDenied();
            }
            output.add({
              'id': itemId,
              'payload': {'kind': 'record', 'record': wire.record(record)},
            });
            continue;
          }
          if (payload['kind'] != 'event') {
            throw const FormatException('Unknown publication kind');
          }
          final envelope = EventEnvelope.fromJson(
            Map<String, dynamic>.from(payload['envelope'] as Map),
            identityCodecs: wire.identities,
          );
          if (envelope.aggregate != channel.aggregate) {
            throw const EventAccessDenied();
          }
          final record = await service.accept(
            _principal(identity),
            envelope,
            expectedChannel: id,
            broadcastLive: false,
          );
          final current = await service.channels.resolve(envelope.aggregate);
          if (current.id != id) {
            // Access-change publication was processed. Its payload must not go
            // back to the retired physical subscription, including the remover.
            if (service.broadcast == null) {
              throw StateError('Rotation requires a live relay');
            }
            await service.broadcast!(current, record);
            output.add({
              'id': itemId,
              'payload': {'kind': 'refresh'},
            });
          } else {
            output.add({
              'id': itemId,
              'payload': {'kind': 'record', 'record': wire.record(record)},
            });
          }
        } on EventAccessDenied {
          output.add({'id': itemId, 'error': 'FORBIDDEN'});
        } on RepositoryException catch (error) {
          output.add({
            'id': itemId,
            'error': error.type == RepositoryExceptionType.duplicate ||
                    error.type == RepositoryExceptionType.constraint
                ? 'INVALID_EVENT'
                : 'RETRYABLE_ACCEPTANCE',
          });
        } on FormatException {
          output.add({'id': itemId, 'error': 'INVALID_EVENT'});
        } catch (error, stack) {
          if (error is ArgumentError ||
              error is TypeError ||
              error is SerializationException) {
            output.add({'id': itemId, 'error': 'INVALID_EVENT'});
            continue;
          }
          service.logger
              .severe('AppSync event processing failed', error, stack);
          output.add({'id': itemId, 'error': 'RETRYABLE_ACCEPTANCE'});
        }
      }
    } catch (error, stack) {
      service.logger
          .warning('Invalid AppSync publish invocation', error, stack);
      return {
        'error': 'Invalid invocation',
        'events': <Map<String, dynamic>>[],
      };
    }
    return {'events': output};
  }
}

/// Optional HTTP bridge authenticated with a backend-only HMAC request signature.
/// The CloudFormation default uses DIRECT Lambda and does not require this route.
class AppSyncHttpBridge<C> {
  AppSyncHttpBridge({
    required this.handlers,
    required this.secret,
    this.tolerance = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (secret.length < 32) {
      throw ArgumentError('Bridge secret must contain at least 32 characters');
    }
  }
  final AppSyncEventHandlers<C> handlers;
  final String secret;
  final Duration tolerance;
  final DateTime Function() _clock;
  Future<Response> handle(Request request) async {
    try {
      if (request.method != 'POST') return Response(405);
      final time = request.headers['x-dddart-appsync-time'] ?? '';
      final seconds = int.parse(time);
      if (_clock()
              .toUtc()
              .difference(
                DateTime.fromMillisecondsSinceEpoch(
                  seconds * 1000,
                  isUtc: true,
                ),
              )
              .abs() >
          tolerance) {
        return Response(403);
      }
      final bytes = <int>[];
      await for (final chunk in request.read()) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) return Response(413);
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final expected = signature(secret, request.requestedUri.path, time, body);
      final supplied = request.headers['x-dddart-appsync-signature'] ?? '';
      var difference = expected.length ^ supplied.length;
      for (var index = 0; index < expected.length; index++) {
        difference |= expected.codeUnitAt(index) ^
            (index < supplied.length ? supplied.codeUnitAt(index) : 0);
      }
      if (difference != 0) return Response(403);
      final result =
          await handlers.handle(jsonDecode(body) as Map<String, dynamic>);
      return Response.ok(
        jsonEncode(result),
        headers: {
          'content-type': 'application/json',
          'cache-control': 'no-store',
        },
      );
    } catch (_) {
      return Response(403);
    }
  }

  static String signature(
    String secret,
    String path,
    String timestamp,
    String body,
  ) =>
      Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('$timestamp\n$path\n$body'))
          .toString();
}
