import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// An explicit stable wire key for a generated event registration.
///
/// Without this annotation the declared class name is the wire key. Renaming
/// that class then requires a wire migration. No runtime name is transmitted.
class DistributedEvent {
  /// Freezes [key] independently of the Dart class name.
  const DistributedEvent(this.key);

  /// Stable versioned event discriminator.
  final String key;
}

/// Instance-local, explicitly registered event and aggregate identity codecs.
class EventRegistry {
  /// Creates a registry with stock UUID aggregate identity support.
  EventRegistry({IdentityCodecRegistry? identityCodecs})
      : identityCodecs = identityCodecs ?? IdentityCodecRegistry();

  /// Codecs shared by envelopes and concrete event serializers.
  final IdentityCodecRegistry identityCodecs;
  final Map<String, _EventEntry> _keys = {};
  final Map<Type, _EventEntry> _types = {};

  /// Registers a stable key and typed explicit JSON callbacks.
  ///
  /// Callbacks must preserve eventId, occurredAt, aggregateId and context as well
  /// as application fields. No implicit dynamic toJson fallback is used.
  void register<E extends DomainEvent<Identity>>(
    String key, {
    required Map<String, dynamic> Function(E) encode,
    required E Function(Map<String, dynamic>) decode,
  }) {
    if (key.isEmpty ||
        key.trim() != key ||
        _keys.containsKey(key) ||
        _types.containsKey(E)) {
      throw ArgumentError('Duplicate or invalid event registration');
    }
    final entry = _EventEntry(
      key: key,
      type: E,
      encode: (event) => encode(event as E),
      decode: decode,
    );
    _keys[key] = entry;
    _types[E] = entry;
  }

  /// Registers an existing JSON serializer rather than duplicating its logic.
  void registerSerializer<E extends DomainEvent<Identity>>(
    String key,
    JsonSerializer<E> serializer,
  ) =>
      register<E>(key, encode: serializer.toJson, decode: serializer.fromJson);

  /// Whether this stable event kind can be reconstructed.
  bool containsKey(String key) => _keys.containsKey(key);

  _EventEntry _entry(DomainEvent<Identity> event) =>
      _types[event.runtimeType] ??
      (throw const SerializationException('No event codec registered'));

  /// The explicitly registered wire key for a concrete event kind.
  String keyFor(DomainEvent<Identity> event) => _entry(event).key;

  /// Encodes only through a registered callback and verifies base metadata.
  Map<String, dynamic> encode(DomainEvent<Identity> event) {
    // Fail before storage/transport if its aggregate kind cannot be represented.
    identityCodecs.toTaggedJson(event.aggregateId);
    final entry = _entry(event);
    try {
      final json = entry.encode(event);
      final restored = entry.decode(json);
      _verify(entry, restored);
      if (_EventMetadata(restored) != _EventMetadata(event)) {
        throw const SerializationException(
          'Event codec does not preserve metadata',
        );
      }
      return json;
    } catch (error) {
      if (error is SerializationException) rethrow;
      throw const SerializationException('Invalid event encoding');
    }
  }

  /// Reconstructs the registered event type and validates its identity codec.
  DomainEvent<Identity> decode(String key, Map<String, dynamic> json) {
    final entry = _keys[key];
    if (entry == null) {
      throw const DeserializationException('Unknown event codec key');
    }
    try {
      final event = entry.decode(json);
      _verify(entry, event);
      identityCodecs.toTaggedJson(event.aggregateId);
      return event;
    } catch (_) {
      throw const DeserializationException(
        'Invalid event payload or identity codec',
      );
    }
  }

  static void _verify(_EventEntry entry, DomainEvent<Identity> event) {
    if (event.runtimeType != entry.type) {
      throw const DeserializationException(
        'Event codec returned a different kind',
      );
    }
  }
}

class _EventEntry {
  _EventEntry({
    required this.key,
    required this.type,
    required this.encode,
    required this.decode,
  });
  final String key;
  final Type type;
  final Map<String, dynamic> Function(DomainEvent<Identity>) encode;
  final DomainEvent<Identity> Function(Map<String, dynamic>) decode;
}

class _EventMetadata extends Value {
  const _EventMetadata(this.event);
  final DomainEvent<Identity> event;
  @override
  List<Object?> get props =>
      [event.eventId, event.aggregateId, event.occurredAt, event.context];
}
