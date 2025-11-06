import 'dart:convert';
import 'package:dddart_serialization/dddart_serialization.dart';

/// JSON-specific serializer interface.
/// 
/// Implements the base [Serializer] interface to provide JSON-specific methods
/// for working with [Map<String, dynamic>] representations.
/// 
/// Serializers can be configured with a default [SerializationConfig] at construction time,
/// and individual method calls can optionally override this configuration.
abstract interface class JsonSerializer<T> implements Serializer<T> {
  /// Converts an object to a JSON-serializable map.
  /// 
  /// Uses the serializer's default configuration, or the provided [config] if specified.
  /// 
  /// This method should be implemented by generated serializer classes
  /// to convert domain objects to Map<String, dynamic> representations.
  Map<String, dynamic> toJson(T object, [SerializationConfig? config]);
  
  /// Reconstructs an object from a JSON map.
  /// 
  /// Uses the serializer's default configuration, or the provided [config] if specified.
  /// 
  /// This method should be implemented by generated serializer classes
  /// to convert Map<String, dynamic> representations back to domain objects.
  /// 
  /// Throws [DeserializationException] if the JSON is invalid or missing required fields.
  T fromJson(dynamic json, [SerializationConfig? config]);
  
  /// Serializes an object to JSON string.
  /// 
  /// Uses the serializer's default configuration, or the provided [config] if specified.
  @override
  String serialize(T object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (e) {
      throw SerializationException(
        'Failed to serialize object to JSON: $e',
        expectedType: T.toString(),
      );
    }
  }
  
  /// Deserializes a JSON string to an object.
  /// 
  /// Uses the serializer's default configuration, or the provided [config] if specified.
  @override
  T deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object but got ${json.runtimeType}',
          expectedType: T.toString(),
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } catch (e) {
      if (e is DeserializationException) rethrow;
      throw DeserializationException(
        'Failed to deserialize JSON: $e',
        expectedType: T.toString(),
      );
    }
  }
}