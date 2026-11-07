import 'package:dddart/dddart.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

class Changed extends DomainEvent<UuidValue> {
  Changed({
    required super.aggregateId,
    this.label = 'changed',
    super.eventId,
    super.occurredAt,
    super.context,
  });
  factory Changed.fromJson(Map<String, dynamic> json) => Changed(
        aggregateId: UuidValue.fromString(json['aggregateId'] as String),
        eventId: UuidValue.fromString(json['eventId'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        context: Map<String, dynamic>.from(json['context'] as Map),
        label: json['label'] as String,
      );
  final String label;
  Map<String, dynamic> toJson() => {
        'eventId': eventId.uuid,
        'aggregateId': aggregateId.uuid,
        'occurredAt': occurredAt.toIso8601String(),
        'context': context,
        'label': label,
      };
}

class EventFixture {
  EventFixture() {
    registry.register<Changed>(
      'changed.v1',
      encode: (event) => event.toJson(),
      decode: Changed.fromJson,
    );
    service = AggregateEventService(
      history: history,
      channels: channels,
      registry: registry,
      policy: policy,
      rotatesAccess: (event) => event is Changed && event.label == 'removed',
      broadcast: (channel, record) async {
        broadcasts.add((channel, record));
        await onBroadcast?.call(channel, record);
      },
      refresh: (channel) async {
        refreshes.add(channel);
        await onRefresh?.call(channel);
      },
      onEvent: (_) async {
        handled++;
      },
    );
  }
  final registry = EventRegistry();
  final history = InMemoryAggregateEventRepository();
  final channels = InMemoryEventChannelRepository();
  final policy = TestPolicy();
  late final AggregateEventService<Map<String, dynamic>> service;
  final broadcasts = <(EventChannel, RecordedEvent)>[];
  final refreshes = <EventChannel>[];
  int handled = 0;
  Future<void> Function(EventChannel, RecordedEvent)? onBroadcast;
  Future<void> Function(EventChannel)? onRefresh;
  AggregateEventWire get wire => AggregateEventWire(registry.identityCodecs);
  AggregateReference<UuidValue> reference([String kind = 'game']) {
    final ref = AggregateReference(kind: kind, id: UuidValue.generate());
    policy.members[ref] = {'alice', 'bob'};
    return ref;
  }

  Future<EventPrincipal<Map<String, dynamic>>?> authenticate(
    String token,
  ) async {
    if (!token.startsWith('valid:')) return null;
    final user = token.substring(6);
    return EventPrincipal(
      userId: user,
      claims: {
        'sub': user,
        'iss': 'issuer',
        'aud': 'app',
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      },
    );
  }

  AppSyncEventHandlers<Map<String, dynamic>> handlers({
    EventAuthenticator<Map<String, dynamic>>? verifier,
  }) =>
      AppSyncEventHandlers(
        service: service,
        namespace: 'aggregates',
        authenticate: verifier ?? authenticate,
        encodeClaims: (claims) => claims,
        decodeClaims: (json) => json,
        nativeIssuer: 'issuer',
        nativeAudience: 'app',
        trustedRelay: (identity) =>
            identity['userArn'] ==
                'arn:aws:sts::123:assumed-role/backend/runtime' &&
            identity['claims'] == null &&
            identity['handlerContext'] == null,
      );
  EventEnvelope envelope(
    AggregateReference<Identity> reference, {
    String label = 'changed',
    UuidValue? id,
  }) =>
      EventEnvelope(
        aggregate: reference,
        event: StoredEvent<Identity>.fromDomainEvent(
          Changed(
            aggregateId: reference.id as UuidValue,
            label: label,
            eventId: id,
          ),
          registry: registry,
        ),
      );
  Map<String, dynamic> invocation(
    String operation,
    EventChannel channel,
    Map<String, dynamic> identity, {
    List<Map<String, dynamic>> events = const [],
  }) =>
      {
        'info': {
          'operation': operation,
          'channel': {
            'path': channel.path('aggregates'),
            'segments': ['aggregates', channel.id.uuid],
          },
          'channelNamespace': {'name': 'aggregates'},
        },
        'identity': identity,
        if (operation == 'PUBLISH') 'events': events,
      };
}

class TestPolicy implements AggregateEventPolicy<Map<String, dynamic>> {
  final Map<AggregateReference<Identity>, Set<String>> members = {};
  @override
  Future<bool> canSubscribe(
    EventPrincipal<Map<String, dynamic>> principal,
    AggregateReference<Identity> aggregate,
  ) async =>
      members[aggregate]?.contains(principal.userId) ?? false;
  @override
  Future<bool> canPublish(
    EventPrincipal<Map<String, dynamic>> principal,
    EventEnvelope envelope,
  ) async =>
      principal.userId == 'alice' &&
      await canSubscribe(principal, envelope.aggregate);
}
