import 'dart:convert';

import 'package:dddart_serialization/dddart_serialization.dart';

/// JSON serializers with typed configuration and shared error boundaries.
///
/// Extend this class for handwritten serializers. Implement [toJson] and
/// [fromJson], using [encodeValue] around encoding and [readValue] around field
/// decoding. Keep application constructors outside field decoding closures so
/// their programming errors remain visible. Generated serializers follow the
/// same contract. See docs/SERIALIZATION.md in the repository.
abstract class JsonSerializer<T> implements Serializer<T, SerializationConfig> {
  /// Converts to a JSON-compatible map using the default or per-call config.
  Map<String, dynamic> toJson(T object, [SerializationConfig? config]);

  /// Decodes an object map; invalid shape/fields throw DeserializationException.
  T fromJson(dynamic json, [SerializationConfig? config]);

  @override
  String serialize(T object, [SerializationConfig? config]) => encodeValue(
        () => jsonEncode(toJson(object, config)),
        expectedType: '$T',
      );

  @override
  T deserialize(String data, [SerializationConfig? config]) {
    final json = readValue(
      () => jsonDecode(data),
      expectedType: '$T',
      message: 'Failed to deserialize JSON',
    );
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: '$T',
      );
    }
    return fromJson(json, config);
  }

  /// Normalizes explicit codec validation and unencodable JSON output.
  ///
  /// Existing typed exceptions and unrelated application errors pass through.
  /// Map encoders and generated/string serializers share this boundary.
  static R encodeValue<R>(R Function() encode, {String? expectedType}) {
    try {
      return encode();
    } on FormatException catch (error, stack) {
      throw SerializationException(
        'Invalid value for JSON serialization: $error',
        expectedType: expectedType,
        cause: error,
        stackTrace: stack,
      );
      // The JSON encoder represents unsupported input as an Error.
      // ignore: avoid_catching_errors
    } on JsonUnsupportedObjectError catch (error, stack) {
      throw SerializationException(
        'Value cannot be encoded as JSON: $error',
        expectedType: expectedType,
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Decodes a declared enum name with an explicit input-validation failure.
  static E readEnum<E extends Enum>(Iterable<E> values, Object? input) {
    for (final value in values) {
      if (value.name == input) return value;
    }
    throw FormatException('Unknown enum value', input);
  }

  /// Decodes one input value, preserving typed errors and their identity.
  ///
  /// FormatException and TypeError at this boundary indicate malformed input.
  /// Do not place arbitrary application work inside [read]; other errors and
  /// exceptions are deliberately not relabeled as invalid input.
  static R readValue<R>(
    R Function() read, {
    String? expectedType,
    String? field,
    String message = 'Failed to deserialize',
  }) {
    try {
      return read();
    } on FormatException catch (error, stack) {
      throw DeserializationException(
        '$message: $error',
        expectedType: expectedType,
        field: field,
        cause: error,
        stackTrace: stack,
      );
      // A field cast is an input-shape check at this explicit boundary.
      // ignore: avoid_catching_errors
    } on TypeError catch (error, stack) {
      throw DeserializationException(
        '$message: $error',
        expectedType: expectedType,
        field: field,
        cause: error,
        stackTrace: stack,
      );
    }
  }
}
