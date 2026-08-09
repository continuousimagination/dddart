import 'dart:convert';

import 'package:dddart_json/dddart_json.dart';

/// Adapts simple string-based test serializers to the JSON-specific contract.
abstract class TestJsonSerializer<T> implements JsonSerializer<T> {
  @override
  Map<String, dynamic> toJson(T object, [dynamic config]) {
    final value = jsonDecode(serialize(object, config));
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object but got ${value.runtimeType}',
      );
    }
    return value;
  }

  @override
  T fromJson(dynamic json, [dynamic config]) {
    return deserialize(jsonEncode(json), config);
  }
}
