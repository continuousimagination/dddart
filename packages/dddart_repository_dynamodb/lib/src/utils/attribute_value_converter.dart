import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';

/// Utilities for converting between JSON and DynamoDB AttributeValue format.
///
/// DynamoDB uses a typed attribute value format where each value is wrapped
/// in a type descriptor. This class provides bidirectional conversion between
/// standard JSON and DynamoDB's AttributeValue format.
///
/// Conversion rules:
/// - null → AttributeValue(nul: true)
/// - bool → AttributeValue(bool: value)
/// - String → AttributeValue(s: value)
/// - num → AttributeValue(n: value.toString())
/// - List → AttributeValue(l: [converted items])
/// - Map → AttributeValue(m: {converted entries})
class AttributeValueConverter {
  /// Converts a JSON value to DynamoDB AttributeValue.
  ///
  /// Takes a standard Dart/JSON value and converts it to DynamoDB's
  /// AttributeValue object.
  ///
  /// Example:
  /// ```dart
  /// jsonToAttributeValue('hello') // Returns: AttributeValue(s: 'hello')
  /// jsonToAttributeValue(42) // Returns: AttributeValue(n: '42')
  /// jsonToAttributeValue(null) // Returns: AttributeValue(nul: true)
  /// ```
  static AttributeValue jsonToAttributeValue(dynamic value) {
    if (value == null) {
      return AttributeValue(nullValue: true);
    } else if (value is bool) {
      return AttributeValue(boolValue: value);
    } else if (value is String) {
      return AttributeValue(s: value);
    } else if (value is num) {
      return AttributeValue(n: value.toString());
    } else if (value is List) {
      return AttributeValue(
        l: value.map(jsonToAttributeValue).toList(),
      );
    } else if (value is Map<String, dynamic>) {
      return AttributeValue(m: jsonMapToAttributeMap(value));
    } else {
      throw ArgumentError(
        'Unsupported type for DynamoDB conversion: ${value.runtimeType}',
      );
    }
  }

  /// Converts a DynamoDB AttributeValue to JSON format.
  ///
  /// Takes a DynamoDB AttributeValue and converts
  /// it back to a standard Dart/JSON value.
  ///
  /// Example:
  /// ```dart
  /// attributeValueToJson(AttributeValue(s: 'hello')) // Returns: 'hello'
  /// attributeValueToJson(AttributeValue(n: '42')) // Returns: 42
  /// attributeValueToJson(AttributeValue(nul: true)) // Returns: null
  /// ```
  static dynamic attributeValueToJson(AttributeValue attr) {
    if (attr.nullValue ?? false) {
      return null;
    } else if (attr.boolValue != null) {
      return attr.boolValue;
    } else if (attr.s != null) {
      return attr.s;
    } else if (attr.n != null) {
      final numStr = attr.n!;
      // Try to parse as int first, then double
      final intValue = int.tryParse(numStr);
      if (intValue != null) {
        return intValue;
      }
      return double.parse(numStr);
    } else if (attr.l != null) {
      return attr.l!.map(attributeValueToJson).toList();
    } else if (attr.m != null) {
      return attributeMapToJsonMap(attr.m!);
    } else {
      throw ArgumentError(
        'Unsupported AttributeValue format: $attr',
      );
    }
  }

  /// Converts a JSON map to DynamoDB AttributeValue map.
  ///
  /// Takes a map of JSON values and converts each value to DynamoDB's
  /// AttributeValue.
  ///
  /// Example:
  /// ```dart
  /// jsonMapToAttributeMap({'name': 'John', 'age': 30})
  /// // Returns: {'name': AttributeValue(s: 'John'), 'age': AttributeValue(n: '30')}
  /// ```
  static Map<String, AttributeValue> jsonMapToAttributeMap(
    Map<String, dynamic> json,
  ) {
    return json.map(
      (key, value) => MapEntry(key, jsonToAttributeValue(value)),
    );
  }

  /// Converts a DynamoDB AttributeValue map to JSON map.
  ///
  /// Takes a map of DynamoDB AttributeValues and converts each value
  /// back to standard JSON format.
  ///
  /// Example:
  /// ```dart
  /// attributeMapToJsonMap({'name': AttributeValue(s: 'John'), 'age': AttributeValue(n: '30')})
  /// // Returns: {'name': 'John', 'age': 30}
  /// ```
  static Map<String, dynamic> attributeMapToJsonMap(
    Map<String, AttributeValue> attrs,
  ) {
    return attrs.map(
      (key, value) => MapEntry(key, attributeValueToJson(value)),
    );
  }
}
