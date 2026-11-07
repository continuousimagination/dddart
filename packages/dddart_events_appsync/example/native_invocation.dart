import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

import 'lib/example_domain.dart';

/// Finite local invocation example, with explicit test-only authentication.
Future<void> main() async {
  final registry = exampleRegistry();
  final channels = InMemoryEventChannelRepository();
  final service = AggregateEventService<String>(
      history: InMemoryAggregateEventRepository(),
      channels: channels,
      registry: registry,
      policy: _LocalPolicy());
  final handlers = AppSyncEventHandlers<String>(
      service: service,
      namespace: 'aggregates',
      authenticate: (token) async => token == 'local-example'
          ? EventPrincipal(userId: 'example', claims: 'example')
          : null,
      encodeClaims: (value) => {'user': value},
      decodeClaims: (json) => json['user'] as String,
      trustedRelay: (_) => false);
  final authorized = await handlers.authorize({
    'authorizationToken': 'local-example',
    'requestContext': {'operation': 'EVENT_CONNECT'}
  });
  if (authorized['isAuthorized'] != true) {
    throw StateError('Local authorization failed');
  }
  final channel = await channels
      .resolve(AggregateReference(kind: 'game', id: UuidValue.generate()));
  final result = await handlers.onSubscribe({
    'identity': {'handlerContext': authorized['handlerContext']},
    'info': {
      'operation': 'SUBSCRIBE',
      'channel': {'path': channel.path('aggregates')}
    }
  });
  if (result != null) throw StateError('Local subscription failed');
  print('Native authorizer and subscription contracts passed locally.');
}

class _LocalPolicy implements AggregateEventPolicy<String> {
  @override
  Future<bool> canSubscribe(EventPrincipal<String> principal,
          AggregateReference<Identity> aggregate) async =>
      principal.userId == 'example';
  @override
  Future<bool> canPublish(
          EventPrincipal<String> principal, EventEnvelope envelope) async =>
      false;
}
