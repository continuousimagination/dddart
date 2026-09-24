import 'dart:convert';

import 'package:dddart_json/dddart_json.dart';

/// Adapts an example's string-based JSON methods to [JsonSerializer].
abstract class ExampleJsonSerializer<T> implements JsonSerializer<T> {
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
