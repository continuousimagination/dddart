import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_events_dynamodb/dddart_events_dynamodb.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_rest/credentials.dart';
import 'package:dddart_rest/http.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'lib/example_domain.dart';

/// Complete custom-runtime entrypoint. Compile locally; run only inside Lambda.
/// Application ACL rows use pk='acl#<canonical logical key>', sk='acl',
/// subscribers/publishers String Sets. The application updates ACLs before events.
Future<void> main() async {
  final env = io.Platform.environment;
  String required(String key) =>
      env[key] ?? (throw StateError('$key is required'));
  final runtime = required('AWS_LAMBDA_RUNTIME_API');
  final region = required('AWS_REGION');
  final table = required('EVENT_TABLE');
  final namespace = env['EVENT_NAMESPACE'] ?? 'aggregates';
  final registry = exampleRegistry();
  final connection = DynamoConnection(region: region);
  final policy =
      _DynamoAclPolicy(connection.client, table, registry.identityCodecs);
  final CredentialVerifier<Map<String, dynamic>> verifier =
      env['AUTH_MODE'] == 'AWS_LAMBDA'
          ? JwtCredentialVerifier(
              secret: required('JWT_SECRET'),
              issuer: required('TOKEN_ISSUER'),
              audience: required('TOKEN_AUDIENCE'),
              parseClaimsFromJson: (json) => json)
          : OAuthJwtAuthHandler(
              jwksUri: required('NATIVE_JWKS_URI'),
              issuer: required('TOKEN_ISSUER'),
              audience: required('TOKEN_AUDIENCE'),
              parseClaimsFromJson: (json) => json);
  Future<EventPrincipal<Map<String, dynamic>>?> authenticate(
      String token) async {
    final result = await verifier.verifyCredential(token);
    if (!result.isAuthenticated ||
        result.userId == null ||
        result.claims == null) {
      return null;
    }
    return EventPrincipal(userId: result.userId!, claims: result.claims!);
  }

  final wire = AggregateEventWire(registry.identityCodecs);
  final retention =
      Duration(days: int.parse(env['EVENT_RETENTION_DAYS'] ?? '7'));
  final authorizerOnly = env['DDDART_MODE'] == 'authorizer';
  final relay = authorizerOnly
      ? null
      : AppSyncHttpPublisher(
          endpoint: Uri.parse(required('EVENT_HTTP_ENDPOINT')),
          namespace: namespace,
          wire: wire,
          authorization: AppSyncIamAuthorization(
              region: region,
              credentials: () async => AppSyncAwsCredentials(
                  accessKey: required('AWS_ACCESS_KEY_ID'),
                  secretKey: required('AWS_SECRET_ACCESS_KEY'),
                  sessionToken: required('AWS_SESSION_TOKEN'))).headers,
        );
  final service = AggregateEventService<Map<String, dynamic>>(
    history: DynamoAggregateEventRepository(
        client: connection.client, tableName: table, retention: retention),
    channels: DynamoEventChannelRepository(
        client: connection.client,
        tableName: table,
        rotationRetention: retention),
    registry: registry,
    policy: policy,
    broadcast: relay?.send, refresh: relay?.refresh,
    // The example uses one registered event with a message discriminant.
    // Real applications normally register a dedicated PlayerRemoved event type.
    rotatesAccess: (event) =>
        event is ExampleChanged && event.message == 'access-changed',
  );
  final handlers = AppSyncEventHandlers<Map<String, dynamic>>(
    service: service,
    namespace: namespace,
    authenticate: authenticate,
    encodeClaims: (claims) => claims,
    decodeClaims: (json) => json,
    nativeIssuer: env['TOKEN_ISSUER'],
    nativeAudience: env['TOKEN_AUDIENCE'],
    trustedRelay: (identity) {
      if (identity['claims'] != null || identity['handlerContext'] != null) {
        return false;
      }
      final role = env['TRUSTED_RELAY_ROLE'];
      final arn = identity['userArn'];
      if (role == null || arn is! String) return false;
      final components = role.split(':');
      final roleName = role.split('/').last;
      return arn.startsWith(
          'arn:${components[1]}:sts::${components[4]}:assumed-role/$roleName/');
    },
  );
  final endpoints =
      AggregateEventHttpEndpoints(service: service, authenticate: authenticate);
  final app = HttpServer()
    ..addRoute('POST', '/events/resolve', endpoints.resolve)
    ..addRoute('POST', '/events/read', endpoints.read)
    ..addRoute('POST', '/events/target', endpoints.target)
    ..addRoute('POST', '/events/publish', endpoints.publish);
  final httpHandler = app.buildHandler();
  Logger.root.onRecord.listen((record) => io.stdout
      .writeln('${record.level.name} ${record.loggerName}: ${record.message}'));
  final client = io.HttpClient();
  final root = Uri.parse('http://$runtime/2018-06-01/runtime/invocation/');
  while (true) {
    final request = await client.getUrl(root.resolve('next'));
    final response = await request.close();
    final invocationId =
        response.headers.value('lambda-runtime-aws-request-id');
    if (invocationId == null || response.statusCode != 200) {
      throw StateError('Invalid Lambda Runtime API response');
    }
    final invocation = jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
    var endpoint = 'response';
    dynamic result;
    try {
      if (authorizerOnly ||
          invocation['info'] != null ||
          invocation['authorizationToken'] != null) {
        result = await handlers.handle(invocation);
      } else {
        result = await _httpInvocation(invocation, httpHandler);
      }
    } catch (error) {
      endpoint = 'error';
      result = {
        'errorMessage': error.toString(),
        'errorType': 'DartInvocationError'
      };
    }
    final output =
        await client.postUrl(root.resolve('$invocationId/$endpoint'));
    output.headers.contentType = io.ContentType.json;
    output.write(jsonEncode(result));
    final acknowledged = await output.close();
    await acknowledged.drain<void>();
    if (acknowledged.statusCode != 202) {
      throw StateError('Lambda Runtime API rejected the invocation result');
    }
  }
}

Future<Map<String, dynamic>> _httpInvocation(
    Map<String, dynamic> invocation, shelf.Handler handler) async {
  final context =
      Map<String, dynamic>.from(invocation['requestContext'] as Map? ?? {});
  final http = Map<String, dynamic>.from(context['http'] as Map? ?? {});
  final headers = Map<String, String>.from(invocation['headers'] as Map? ?? {});
  final path =
      invocation['rawPath'] as String? ?? invocation['path'] as String? ?? '/';
  final body = invocation['body'] as String? ?? '';
  final request = shelf.Request(
      http['method'] as String? ??
          invocation['httpMethod'] as String? ??
          'POST',
      Uri.parse('https://lambda.local$path'),
      headers: headers,
      body: invocation['isBase64Encoded'] == true
          ? base64Decode(body)
          : utf8.encode(body));
  final response = await handler(request);
  return {
    'statusCode': response.statusCode,
    'headers': response.headers,
    'body': await response.readAsString(),
    'isBase64Encoded': false
  };
}

class _DynamoAclPolicy implements AggregateEventPolicy<Map<String, dynamic>> {
  _DynamoAclPolicy(this.client, this.table, this.identities);
  final DynamoDB client;
  final String table;
  final IdentityCodecRegistry identities;
  Future<bool> _allowed(EventPrincipal<Map<String, dynamic>> principal,
      AggregateReference<Identity> aggregate, String field) async {
    final logical = aggregate.toKey(identities);
    if (utf8.encode('acl#$logical').length > 2048) return false;
    final result = await client.getItem(
        tableName: table,
        key: {
          'pk': AttributeValue(s: 'acl#$logical'),
          'sk': AttributeValue(s: 'acl')
        },
        consistentRead: true);
    return result.item?[field]?.ss?.contains(principal.userId) ?? false;
  }

  @override
  Future<bool> canSubscribe(EventPrincipal<Map<String, dynamic>> principal,
          AggregateReference<Identity> aggregate) =>
      _allowed(principal, aggregate, 'subscribers');
  @override
  Future<bool> canPublish(EventPrincipal<Map<String, dynamic>> principal,
          EventEnvelope envelope) =>
      _allowed(principal, envelope.aggregate, 'publishers');
}
