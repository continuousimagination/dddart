/// Generic interface for serializing objects to and from string representations.
///
/// This interface defines the contract for serialization implementations.
/// Different formats (JSON, YAML, Protocol Buffers, etc.) can implement
/// this interface to provide format-specific serialization.
///
/// [T] is the object type; [C] is the format-specific configuration type.
/// Configuration is statically typed, including through this generic interface.
abstract interface class Serializer<T, C extends Object> {
  /// Serializes an object to its string representation.
  ///
  /// Takes an instance of type [T] and converts it to a string format
  /// that can be stored, transmitted, or otherwise persisted.
  ///
  /// The optional [config] parameter allows overriding the serializer's
  /// default configuration for this specific operation.
  ///
  /// Throws [SerializationException] if serialization fails.
  String serialize(T object, [C? config]);

  /// Deserializes a string representation back to an object.
  ///
  /// Takes a string in the expected format and reconstructs an instance
  /// of type [T] from it.
  ///
  /// The optional [config] parameter allows overriding the serializer's
  /// default configuration for this specific operation.
  ///
  /// Throws [DeserializationException] if deserialization fails.
  T deserialize(String data, [C? config]);
}

/// Base exception for serialization-related errors.
class SerializationException implements Exception {
  /// Creates a serialization exception.
  const SerializationException(
    this.message, {
    this.expectedType,
    this.cause,
    this.stackTrace,
  });

  /// The error message describing what went wrong.
  final String message;

  /// The type that was being serialized when the error occurred.
  final String? expectedType;

  /// Original failure, when a boundary normalizes an input/encoding error.
  final Object? cause;

  /// Stack trace captured at the original failure.
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (expectedType != null) {
      return 'SerializationException: $message (Type: $expectedType)';
    }
    return 'SerializationException: $message';
  }
}

/// Exception thrown when deserialization fails.
class DeserializationException extends SerializationException {
  /// Creates a deserialization exception.
  const DeserializationException(
    super.message, {
    super.expectedType,
    super.cause,
    super.stackTrace,
    this.field,
  });

  /// The field that caused the deserialization error.
  final String? field;

  @override
  String toString() {
    final parts = <String>['DeserializationException: $message'];
    if (expectedType != null) parts.add('Type: $expectedType');
    if (field != null) parts.add('Field: $field');
    return parts.join(' (') + (parts.length > 1 ? ')' : '');
  }
}
