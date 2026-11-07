import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// One PK/SK table with payload TTL and independently durable heads/mappings.
///
/// Inject a DynamoConnection.client or an SDK client with an injected HTTP layer.
/// Construction never creates tables. See deploy/cloudformation.yaml in AppSync.
class DynamoAggregateEventRepository implements AggregateEventRepository {
  DynamoAggregateEventRepository({
    required DynamoDB client,
    required String tableName,
    IdentityCodecRegistry? identityCodecs,
    this.retention = const Duration(days: 7),
    DateTime Function()? clock,
  }) : _store = _Store(
          client,
          tableName,
          identityCodecs ?? IdentityCodecRegistry(),
          clock ?? DateTime.now,
        ) {
    if (retention <= Duration.zero) {
      throw ArgumentError.value(retention, 'retention');
    }
  }
  final _Store _store;
  @override
  final Duration retention;

  @override
  Future<RecordedEvent> append(EventEnvelope envelope) async {
    final logical = envelope.aggregate.toKey(_store.codecs);
    final pk = _store.stream(envelope.aggregate);
    final encoded = envelope.canonicalJson(_store.codecs);
    if (utf8.encode(encoded).length > 240 * 1024) {
      throw const RepositoryException(
        'Event exceeds supported payload size',
        type: RepositoryExceptionType.constraint,
      );
    }
    final digest = sha256.convert(utf8.encode(encoded)).toString();
    for (var attempt = 0; attempt < 24; attempt++) {
      final now = _store.now();
      final existing = await _store.get('e#${envelope.id.uuid}', 'id');
      if (existing.isNotEmpty &&
          _store.number(existing, 'expiresAt') >
              now.millisecondsSinceEpoch ~/ 1000) {
        if (existing['digest']?.s != digest ||
            existing['logical']?.s != logical) {
          throw const RepositoryException(
            'Conflicting event occurrence ID',
            type: RepositoryExceptionType.duplicate,
          );
        }
        return _store.record(existing);
      }
      final head = await _store.head(envelope.aggregate);
      final position = _store.number(head, 'position') + 1;
      final record = <String, AttributeValue>{
        'wire': AttributeValue(s: encoded),
        'logical': AttributeValue(s: logical),
        'position': AttributeValue(n: '$position'),
        'ingestedAt': AttributeValue(s: now.toIso8601String()),
        'ingestedMicros': AttributeValue(n: '${now.microsecondsSinceEpoch}'),
        'expiresAt': AttributeValue(
          n: '${now.add(retention).millisecondsSinceEpoch ~/ 1000}',
        ),
        'digest': AttributeValue(s: digest),
        'kind': AttributeValue(s: 'event'),
      };
      try {
        await _store.client.transactWriteItems(
          transactItems: [
            TransactWriteItem(
              update: Update(
                tableName: _store.table,
                key: _store.key(pk, 'head'),
                updateExpression: 'SET #position = :next, logical = :logical',
                conditionExpression:
                    'attribute_not_exists(pk) OR (#position = :previous AND logical = :logical)',
                expressionAttributeNames: {
                  '#position': 'position',
                },
                expressionAttributeValues: {
                  ':next': AttributeValue(n: '$position'),
                  ':previous': AttributeValue(n: '${position - 1}'),
                  ':logical': AttributeValue(s: logical),
                },
              ),
            ),
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {
                  ...record,
                  ..._store.key(pk, _store.position(position)),
                },
                conditionExpression: 'attribute_not_exists(pk)',
              ),
            ),
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {
                  ...record,
                  ..._store.key('e#${envelope.id.uuid}', 'id'),
                },
                conditionExpression:
                    'attribute_not_exists(pk) OR expiresAt <= :now',
                expressionAttributeValues: {
                  ':now': AttributeValue(
                    n: '${now.millisecondsSinceEpoch ~/ 1000}',
                  ),
                },
              ),
            ),
          ],
        );
        return _store.record(record);
      } on TransactionCanceledException {
        // Read back the occurrence after uncertain or competing writes before
        // reserving any new position. Position+record+dedupe commit atomically.
        await _store.backoff(attempt);
      } on TransactionConflictException {
        await _store.backoff(attempt);
      }
    }
    throw const RepositoryException(
      'Event append contention',
      type: RepositoryExceptionType.connection,
    );
  }

  @override
  Future<void> save(EventEnvelope aggregate) async {
    await append(aggregate);
  }

  @override
  Future<EventEnvelope> getById(UuidValue id) async {
    final item = await _store.get('e#${id.uuid}', 'id');
    if (item.isEmpty ||
        _store.number(item, 'expiresAt') <=
            _store.now().millisecondsSinceEpoch ~/ 1000) {
      throw _notFound();
    }
    return _store.record(item).envelope;
  }

  @override
  Future<EventCheckpoint> head(AggregateReference<Identity> aggregate) async {
    final head = await _store.head(aggregate);
    return EventCheckpoint(
      streamKey: aggregate.toKey(_store.codecs),
      position: _store.number(head, 'position'),
      observedAt: _store.now(),
    );
  }

  @override
  Future<EventPage> read(
    AggregateReference<Identity> aggregate, {
    required EventCheckpoint after,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 1000) throw ArgumentError.value(limit, 'limit');
    final now = _store.now();
    final head = await _store.head(aggregate);
    final high = _store.number(head, 'position');
    final logical = aggregate.toKey(_store.codecs);
    if (after.streamKey != logical ||
        after.position > high ||
        after.observedAt.isAfter(now)) {
      throw ArgumentError('Invalid checkpoint');
    }
    if (!after.observedAt.isAfter(now.subtract(retention)) ||
        after.position < _store.number(head, 'floor')) {
      throw EventHistoryExpired(aggregate);
    }
    if (after.position == high) {
      return EventPage(
        events: const [],
        checkpoint: EventCheckpoint(
          streamKey: logical,
          position: high,
          observedAt: now,
        ),
        hasMore: false,
      );
    }
    final response = await _store.client.query(
      tableName: _store.table,
      consistentRead: true,
      keyConditionExpression: 'pk = :pk AND sk BETWEEN :low AND :high',
      expressionAttributeValues: {
        ':pk': AttributeValue(s: _store.stream(aggregate)),
        ':low': AttributeValue(s: _store.position(after.position + 1)),
        ':high': AttributeValue(s: _store.position(high)),
      },
      limit: limit,
    );
    final items = response.items ?? [];
    var expected = after.position + 1;
    final events = <RecordedEvent>[];
    for (final item in items) {
      // A TTL-lagged payload must not be delivered. Gaps also detect records
      // already removed by TTL even if a caller fabricated a recent anchor.
      if (_store.number(item, 'position') != expected ||
          _store.number(item, 'expiresAt') <=
              now.millisecondsSinceEpoch ~/ 1000) {
        throw EventHistoryExpired(aggregate);
      }
      events.add(_store.record(item));
      expected++;
    }
    if (events.isEmpty) throw EventHistoryExpired(aggregate);
    final last = events.last.position;
    // DynamoDB may stop at 1 MB before Limit. Never advance to head merely
    // because fewer than Limit items were returned; resume from the last record.
    final more = last < high;
    return EventPage(
      events: events,
      checkpoint: EventCheckpoint(
        streamKey: logical,
        position: more ? last : high,
        observedAt: more ? after.observedAt : now,
      ),
      hasMore: more,
    );
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    final item = await _store.get('e#${id.uuid}', 'id');
    if (item.isEmpty) throw _notFound();
    final record = _store.record(item);
    final aggregate = record.envelope.aggregate;
    final pk = _store.stream(aggregate);
    for (var attempt = 0; attempt < 24; attempt++) {
      final head = await _store.head(aggregate);
      final floor = _store.number(head, 'floor');
      try {
        await _store.client.transactWriteItems(
          transactItems: [
            TransactWriteItem(
              delete: Delete(
                tableName: _store.table,
                key: _store.key(pk, _store.position(record.position)),
              ),
            ),
            TransactWriteItem(
              delete: Delete(
                tableName: _store.table,
                key: _store.key('e#${id.uuid}', 'id'),
                conditionExpression:
                    '#position = :position AND digest = :digest AND logical = :logical',
                expressionAttributeNames: {
                  '#position': 'position',
                },
                expressionAttributeValues: {
                  ':position': AttributeValue(n: '${record.position}'),
                  ':digest': item['digest']!,
                  ':logical': item['logical']!,
                },
              ),
            ),
            TransactWriteItem(
              update: Update(
                tableName: _store.table,
                key: _store.key(pk, 'head'),
                updateExpression: 'SET #floor = :floor',
                conditionExpression:
                    'attribute_not_exists(#floor) OR #floor = :old',
                expressionAttributeNames: {
                  '#floor': 'floor',
                },
                expressionAttributeValues: {
                  ':floor': AttributeValue(n: '${max(floor, record.position)}'),
                  ':old': AttributeValue(n: '$floor'),
                },
              ),
            ),
          ],
        );
        return;
      } on TransactionCanceledException {
        await _store.backoff(attempt);
      }
    }
    throw const RepositoryException(
      'Event delete contention',
      type: RepositoryExceptionType.connection,
    );
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    // Explicit maintenance may scan; resolve, append, head and polling never do.
    Map<String, AttributeValue>? cursor;
    do {
      final page = await _store.client.scan(
        tableName: _store.table,
        exclusiveStartKey: cursor,
        filterExpression: 'sk = :id AND ingestedMicros < :cutoff',
        expressionAttributeValues: {
          ':id': AttributeValue(s: 'id'),
          ':cutoff': AttributeValue(n: '${timestamp.microsecondsSinceEpoch}'),
        },
      );
      for (final item in page.items ?? <Map<String, AttributeValue>>[]) {
        final id = _store.record(item).envelope.id;
        try {
          await deleteById(id);
        } on RepositoryException catch (error) {
          if (error.type != RepositoryExceptionType.notFound) rethrow;
        }
      }
      cursor = page.lastEvaluatedKey;
    } while (cursor != null && cursor.isNotEmpty);
  }
}

/// Durable current-channel metadata and idempotent event-driven rotations.
class DynamoEventChannelRepository implements EventChannelRepository {
  DynamoEventChannelRepository({
    required DynamoDB client,
    required String tableName,
    IdentityCodecRegistry? identityCodecs,
    DateTime Function()? clock,
    this.rotationRetention = const Duration(days: 7),
  }) : _store = _Store(
          client,
          tableName,
          identityCodecs ?? IdentityCodecRegistry(),
          clock ?? DateTime.now,
        ) {
    if (rotationRetention <= Duration.zero) {
      throw ArgumentError.value(rotationRetention, 'rotationRetention');
    }
  }
  final _Store _store;
  final Duration rotationRetention;
  String _pk(AggregateReference<Identity> aggregate) =>
      'm#${_store.stream(aggregate)}';
  EventChannel _channel(Map<String, AttributeValue> item) => EventChannel(
        AggregateReference<Identity>.fromJson(
          jsonDecode(item['aggregate']!.s!) as Map<String, dynamic>,
          identityCodecs: _store.codecs,
        ),
        UuidValue.fromString(item['channel']!.s!),
      );
  Map<String, AttributeValue> _item(EventChannel channel) => {
        'aggregate': AttributeValue(
          s: jsonEncode(channel.aggregate.toJson(_store.codecs)),
        ),
        'channel': AttributeValue(s: channel.id.uuid),
        'logical': AttributeValue(s: channel.aggregate.toKey(_store.codecs)),
      };

  @override
  Future<EventChannel> resolve(AggregateReference<Identity> aggregate) async {
    for (var attempt = 0; attempt < 24; attempt++) {
      final item = await _store.get(_pk(aggregate), 'state');
      if (item.isNotEmpty) {
        if (item['logical']?.s != aggregate.toKey(_store.codecs)) {
          throw StateError('Logical key hash collision');
        }
        return _channel(item);
      }
      final channel = EventChannel(aggregate, UuidValue.generate());
      final data = _item(channel);
      try {
        await _store.client.transactWriteItems(
          transactItems: [
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {...data, ..._store.key(_pk(aggregate), 'state')},
                conditionExpression: 'attribute_not_exists(pk)',
              ),
            ),
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {
                  ...data,
                  ..._store.key('c#${channel.id.uuid}', 'current'),
                },
                conditionExpression: 'attribute_not_exists(pk)',
              ),
            ),
          ],
        );
        return channel;
      } on TransactionCanceledException {
        await _store.backoff(attempt);
      }
    }
    throw const RepositoryException(
      'Channel resolution contention',
      type: RepositoryExceptionType.connection,
    );
  }

  @override
  Future<EventChannel?> find(UuidValue channelId) async {
    final item = await _store.get('c#${channelId.uuid}', 'current');
    if (item.isEmpty) return null;
    final channel = _channel(item);
    final current = await _store.get(_pk(channel.aggregate), 'state');
    if (current.isEmpty || current['channel']?.s != channelId.uuid) return null;
    return channel;
  }

  @override
  Future<EventChannelRotation> rotate(
    AggregateReference<Identity> aggregate,
    UuidValue triggerId,
  ) async {
    for (var attempt = 0; attempt < 24; attempt++) {
      final previous = await _store.get('r#${triggerId.uuid}', 'rotation');
      if (previous.isNotEmpty &&
          _store.number(previous, 'expiresAt') >
              _store.now().millisecondsSinceEpoch ~/ 1000) {
        final current = _channel(previous);
        if (current.aggregate != aggregate) {
          throw StateError('Conflicting rotation occurrence');
        }
        return EventChannelRotation(
          EventChannel(
            aggregate,
            UuidValue.fromString(previous['previous']!.s!),
          ),
          current,
        );
      }
      final before = await resolve(aggregate);
      final after = EventChannel(aggregate, UuidValue.generate());
      final data = _item(after);
      final now = _store.now();
      try {
        await _store.client.transactWriteItems(
          transactItems: [
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {...data, ..._store.key(_pk(aggregate), 'state')},
                conditionExpression: 'channel = :previous',
                expressionAttributeValues: {
                  ':previous': AttributeValue(s: before.id.uuid),
                },
              ),
            ),
            TransactWriteItem(
              delete: Delete(
                tableName: _store.table,
                key: _store.key('c#${before.id.uuid}', 'current'),
              ),
            ),
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {
                  ...data,
                  ..._store.key('c#${after.id.uuid}', 'current'),
                },
                conditionExpression: 'attribute_not_exists(pk)',
              ),
            ),
            TransactWriteItem(
              put: Put(
                tableName: _store.table,
                item: {
                  ...data,
                  ..._store.key('r#${triggerId.uuid}', 'rotation'),
                  'previous': AttributeValue(s: before.id.uuid),
                  'expiresAt': AttributeValue(
                    n: '${now.add(rotationRetention).millisecondsSinceEpoch ~/ 1000}',
                  ),
                },
                conditionExpression:
                    'attribute_not_exists(pk) OR expiresAt <= :now',
                expressionAttributeValues: {
                  ':now': AttributeValue(
                    n: '${now.millisecondsSinceEpoch ~/ 1000}',
                  ),
                },
              ),
            ),
          ],
        );
        return EventChannelRotation(before, after);
      } on TransactionCanceledException {
        await _store.backoff(attempt);
      }
    }
    throw const RepositoryException(
      'Channel rotation contention',
      type: RepositoryExceptionType.connection,
    );
  }
}

class _Store {
  _Store(this.client, this.table, this.codecs, this.clock) {
    if (table.isEmpty) throw ArgumentError.value(table, 'tableName');
  }
  final DynamoDB client;
  final String table;
  final IdentityCodecRegistry codecs;
  final DateTime Function() clock;
  DateTime now() => clock().toUtc();
  Map<String, AttributeValue> key(String pk, String sk) =>
      {'pk': AttributeValue(s: pk), 'sk': AttributeValue(s: sk)};
  String stream(AggregateReference<Identity> aggregate) =>
      's#${sha256.convert(utf8.encode(aggregate.toKey(codecs)))}';
  String position(int position) => 'p#${position.toString().padLeft(20, '0')}';
  int number(Map<String, AttributeValue> item, String key) =>
      int.parse(item[key]?.n ?? '0');
  Future<Map<String, AttributeValue>> get(String pk, String sk) async =>
      (await client.getItem(
        tableName: table,
        key: key(pk, sk),
        consistentRead: true,
      ))
          .item ??
      {};
  Future<Map<String, AttributeValue>> head(
    AggregateReference<Identity> aggregate,
  ) async {
    final item = await get(stream(aggregate), 'head');
    if (item.isNotEmpty && item['logical']?.s != aggregate.toKey(codecs)) {
      throw StateError('Logical key hash collision');
    }
    return item;
  }

  RecordedEvent record(Map<String, AttributeValue> item) => RecordedEvent(
        envelope: EventEnvelope.fromJson(
          jsonDecode(item['wire']!.s!) as Map<String, dynamic>,
          identityCodecs: codecs,
        ),
        position: number(item, 'position'),
        ingestedAt: DateTime.parse(item['ingestedAt']!.s!),
      );
  Future<void> backoff(int attempt) => Future<void>.delayed(
        Duration(milliseconds: min(100, 2 * attempt + Random().nextInt(8))),
      );
}

RepositoryException _notFound() => const RepositoryException(
      'Retained event not found',
      type: RepositoryExceptionType.notFound,
    );
