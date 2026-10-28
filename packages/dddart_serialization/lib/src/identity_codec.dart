import 'package:dddart/dddart.dart' show Identity, UuidValue;
import 'package:dddart_serialization/src/serialization_contracts.dart';

/// Explicit JSON and canonical key representations of one identity kind.
///
/// JSON values must be JSON-compatible scalars or structures. Keys must be
/// reversible and collision-free over the identity's supported domain, including
/// its scope. Backend size/type constraints are checked by the selected adapter.
abstract interface class IdentityCodec<I extends Identity> {
  /// Encodes an identity without using an arbitrary toString representation.
  Object toJson(I identity);

  /// Reconstructs and validates an encoded identity.
  I fromJson(Object? value);

  /// Encodes a canonical key; URI escaping is a separate transport concern.
  String toKey(I identity);

  /// Reconstructs and validates a canonical key.
  I fromKey(String value);
}

/// The stock UUID wire/key codec, retaining the UUID string representation.
class UuidIdentityCodec implements IdentityCodec<UuidValue> {
  /// Creates the stateless UUID codec.
  const UuidIdentityCodec();

  @override
  String toJson(UuidValue identity) => identity.uuid;

  @override
  UuidValue fromJson(Object? value) {
    if (value is! String) throw const FormatException('Expected UUID string');
    return UuidValue.fromString(value);
  }

  @override
  String toKey(UuidValue identity) => identity.uuid;

  @override
  UuidValue fromKey(String value) => UuidValue.fromString(value);
}

/// Typed identity codecs with explicit stable keys for heterogeneous streams.
///
/// UUID support is registered as "uuid". Register each concrete application
/// identity kind once; registration keys are part of its wire contract and must
/// not be inferred from runtimeType or toString. No global registry is used.
class IdentityCodecRegistry {
  /// Creates an instance-local registry with the stock UUID codec.
  IdentityCodecRegistry() {
    register<UuidValue>('uuid', const UuidIdentityCodec());
  }

  final Map<Type, _CodecEntry> _types = {};
  final Map<String, _CodecEntry> _keys = {};

  /// Registers a concrete identity kind and its stable wire discriminator.
  ///
  /// Duplicate types/keys are errors, including attempts to replace UUID.
  void register<I extends Identity>(String key, IdentityCodec<I> codec) {
    if (key.isEmpty || key.trim() != key) {
      throw ArgumentError.value(key, 'key', 'Expected nonempty stable key');
    }
    if (_types.containsKey(I) || _keys.containsKey(key)) {
      throw ArgumentError(
        'Identity codec type or registration key already exists',
      );
    }
    final entry = _CodecEntry(
      type: I,
      key: key,
      encode: (value) => codec.toJson(value as I),
      decode: codec.fromJson,
      encodeKey: (value) => codec.toKey(value as I),
      decodeKey: codec.fromKey,
    );
    _types[I] = entry;
    _keys[key] = entry;
  }

  /// Whether the concrete identity type has an explicit codec.
  bool contains<I extends Identity>() => _types.containsKey(I);

  _CodecEntry _entry<I extends Identity>() =>
      _types[I] ??
      (throw SerializationException('No identity codec registered for $I'));

  static void _checkKind(_CodecEntry entry, Identity identity) {
    if (identity.runtimeType != entry.type) {
      throw SerializationException(
        'Identity codec requires concrete kind ${entry.type}',
      );
    }
  }

  /// Encodes a value using its statically declared concrete identity type.
  Object toJson<I extends Identity>(I identity) {
    final entry = _entry<I>();
    _checkKind(entry, identity);
    return entry.encode(identity);
  }

  /// Decodes a value to the requested concrete identity type.
  I fromJson<I extends Identity>(Object? value) =>
      _decode(_entry<I>(), value) as I;

  /// Encodes a canonical key with an explicit typed codec.
  String toKey<I extends Identity>(I identity) {
    final entry = _entry<I>();
    _checkKind(entry, identity);
    try {
      final key = entry.encodeKey(identity);
      final restored = entry.decodeKey(key);
      _checkKind(entry, restored);
      if (restored != identity) {
        throw SerializationException(
          'Identity key codec is not lossless',
          expectedType: '$I',
        );
      }
      return key;
    } catch (error) {
      if (error is SerializationException) rethrow;
      throw SerializationException(
        'Invalid identity key encoding',
        expectedType: '$I',
      );
    }
  }

  /// Decodes a canonical key with the requested identity codec.
  I fromKey<I extends Identity>(String value) {
    final entry = _entry<I>();
    try {
      final identity = entry.decodeKey(value);
      _checkKind(entry, identity);
      if (entry.encodeKey(identity) != value) {
        throw const FormatException('Noncanonical identity key');
      }
      return identity as I;
    } catch (_) {
      throw DeserializationException(
        'Invalid or noncanonical identity key',
        expectedType: '$I',
      );
    }
  }

  /// Encodes kind and value for streams containing several identity types.
  Map<String, Object?> toTaggedJson(Identity identity) {
    final entry = _types[identity.runtimeType];
    if (entry == null) {
      throw SerializationException(
        'No identity codec registered for ${identity.runtimeType}',
      );
    }
    _checkKind(entry, identity);
    return {'type': entry.key, 'value': entry.encode(identity)};
  }

  /// Reconstructs an identity from an explicit registered wire discriminator.
  Identity fromTaggedJson(Object? value) {
    if (value is! Map ||
        value['type'] is! String ||
        !value.containsKey('value')) {
      throw const DeserializationException(
        'Expected tagged identity with type and value',
      );
    }
    final entry = _keys[value['type']];
    if (entry == null) {
      throw const DeserializationException('Unknown identity codec key');
    }
    return _decode(entry, value['value']);
  }

  static Identity _decode(_CodecEntry entry, Object? value) {
    try {
      final identity = entry.decode(value);
      _checkKind(entry, identity);
      return identity;
    } catch (_) {
      throw DeserializationException(
        'Invalid identity value',
        expectedType: '${entry.type}',
      );
    }
  }
}

class _CodecEntry {
  _CodecEntry({
    required this.type,
    required this.key,
    required this.encode,
    required this.decode,
    required this.encodeKey,
    required this.decodeKey,
  });

  final Type type;
  final String key;
  final Object Function(Identity) encode;
  final Identity Function(Object?) decode;
  final String Function(Identity) encodeKey;
  final Identity Function(String) decodeKey;
}
