import 'dart:convert';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/aggregate_event_repository.dart';
import 'package:dddart_events_distributed/src/aggregate_reference.dart';
import 'package:dddart_events_distributed/src/event_envelope.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Instance-local aggregate event history for tests and basic local applications.
///
/// Uses committed ingestion positions rather than occurrence timestamps. There
/// is no await between position allocation and record insertion. It is not shared
/// across serverless invocations or processes; production servers need a durable
/// implementation of [AggregateEventRepository].
class InMemoryAggregateEventRepository implements AggregateEventRepository {
  /// Creates history with a configurable seven-day default retention window.
  InMemoryAggregateEventRepository({
    this.retention = const Duration(days: 7),
    IdentityCodecRegistry? identityCodecs,
    DateTime Function()? clock,
  })  : identityCodecs = identityCodecs ?? IdentityCodecRegistry(),
        _clock = clock ?? DateTime.now {
    if (retention <= Duration.zero) {
      throw ArgumentError.value(retention, 'retention', 'Must be positive');
    }
  }

  @override
  final Duration retention;

  /// Explicit codecs shared with event serializers and aggregate references.
  final IdentityCodecRegistry identityCodecs;
  final DateTime Function() _clock;
  final Map<UuidValue, _Entry> _entries = {};
  final Map<String, List<_Entry>> _streams = {};
  final Map<String, int> _heads = {};
  final Map<String, int> _deletedThrough = {};

  @override
  Future<RecordedEvent> append(EventEnvelope envelope) async {
    final now = _clock().toUtc();
    _expire(now);
    final key = envelope.aggregate.toKey(identityCodecs);
    final wire = _encode(envelope);
    final previous = _entries[envelope.id];
    if (previous != null) {
      if (previous.streamKey != key || previous.wire != wire) {
        throw const RepositoryException(
          'Conflicting reuse of event occurrence ID',
          type: RepositoryExceptionType.duplicate,
        );
      }
      return _restore(previous);
    }
    final position = (_heads[key] ?? 0) + 1;
    final entry = _Entry(envelope.id, key, position, now, wire);
    _entries[envelope.id] = entry;
    (_streams[key] ??= []).add(entry);
    _heads[key] = position;
    return _restore(entry);
  }

  @override
  Future<void> save(EventEnvelope aggregate) async {
    await append(aggregate);
  }

  @override
  Future<EventEnvelope> getById(UuidValue id) async {
    _expire(_clock().toUtc());
    final entry = _entries[id];
    if (entry == null) throw _notFound();
    return _restore(entry).envelope;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    _expire(_clock().toUtc());
    final entry = _entries[id];
    if (entry == null) throw _notFound();
    _remove(entry);
  }

  @override
  Future<EventCheckpoint> head(AggregateReference<Identity> aggregate) async {
    final now = _clock().toUtc();
    _expire(now);
    final key = aggregate.toKey(identityCodecs);
    return EventCheckpoint(
      streamKey: key,
      position: _heads[key] ?? 0,
      observedAt: now,
    );
  }

  @override
  Future<EventPage> read(
    AggregateReference<Identity> aggregate, {
    required EventCheckpoint after,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Expected 1 through 1000');
    }
    final now = _clock().toUtc();
    final key = aggregate.toKey(identityCodecs);
    if (after.streamKey != key ||
        after.position > (_heads[key] ?? 0) ||
        after.observedAt.isAfter(now)) {
      throw ArgumentError('Checkpoint does not belong to this stream/head');
    }
    _expire(now);
    if (!after.observedAt.isAfter(now.subtract(retention)) ||
        after.position < (_deletedThrough[key] ?? 0)) {
      throw EventHistoryExpired(aggregate);
    }
    final head = _heads[key] ?? 0;
    final page = (_streams[key] ?? const <_Entry>[])
        .where((entry) => entry.position > after.position)
        .take(limit + 1)
        .toList();
    final hasMore = page.length > limit;
    final selected = page.take(limit).toList();
    return EventPage(
      events: selected.map(_restore),
      hasMore: hasMore,
      checkpoint: EventCheckpoint(
        streamKey: key,
        position: hasMore ? selected.last.position : head,
        // Renew only after complete recovery. Renewing an incomplete page could
        // hide expiration of older unread records while the client is paging.
        observedAt: hasMore ? after.observedAt : now,
      ),
    );
  }

  @override
  Future<void> deleteOlderThan(DateTime timestamp) async {
    final cutoff = timestamp.toUtc();
    for (final entry in _entries.values
        .where((entry) => entry.ingestedAt.isBefore(cutoff))
        .toList()) {
      _remove(entry);
    }
  }

  void _expire(DateTime now) {
    final cutoff = now.subtract(retention);
    for (final entry in _entries.values
        .where((entry) => !entry.ingestedAt.isAfter(cutoff))
        .toList()) {
      _remove(entry);
    }
  }

  void _remove(_Entry entry) {
    _entries.remove(entry.id);
    _streams[entry.streamKey]?.remove(entry);
    _deletedThrough[entry.streamKey] = max(
      _deletedThrough[entry.streamKey] ?? 0,
      entry.position,
    );
  }

  RecordedEvent _restore(_Entry entry) => RecordedEvent(
        envelope: EventEnvelope.fromJson(
          jsonDecode(entry.wire) as Map<String, dynamic>,
          identityCodecs: identityCodecs,
        ),
        position: entry.position,
        ingestedAt: entry.ingestedAt,
      );

  String _encode(EventEnvelope envelope) {
    final json = envelope.toJson(identityCodecs);
    final event = json['event'] as Map<String, dynamic>;
    try {
      event['eventJson'] = jsonEncode(
        _canonical(jsonDecode(event['eventJson'] as String)),
      );
    } on FormatException {
      // History retains malformed payloads for the client's explicit log/skip
      // policy. The publication envelope/reference itself must remain valid.
    }
    return jsonEncode(_canonical(json));
  }

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  RepositoryException _notFound() => const RepositoryException(
        'Retained event not found',
        type: RepositoryExceptionType.notFound,
      );
}

class _Entry {
  _Entry(this.id, this.streamKey, this.position, this.ingestedAt, this.wire);

  final UuidValue id;
  final String streamKey;
  final int position;
  final DateTime ingestedAt;
  final String wire;
}
