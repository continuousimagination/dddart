// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class MoneyJsonSerializer implements JsonSerializer<Money> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  MoneyJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig =
          defaultConfig ??
          const SerializationConfig(
            fieldRename: FieldRename.none,
            includeNullFields: false,
          );

  @override
  Map<String, dynamic> toJson(Money instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'amount',
        effectiveConfig.fieldRename,
      ): instance.amount,
      SerializationUtils.applyFieldRename(
        'currency',
        effectiveConfig.fieldRename,
      ): instance.currency,
    };
    return json;
  }

  @override
  Money fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Money from null JSON',
        expectedType: 'Money',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Money',
      );
    }
    try {
      return Money(
        amount:
            (json[SerializationUtils.applyFieldRename(
                  'amount',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'amount',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'amount',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        currency:
            json[SerializationUtils.applyFieldRename(
                  'currency',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e) {
      throw DeserializationException(
        'Failed to deserialize Money',
        expectedType: 'Money',
      );
    }
  }

  @override
  String serialize(Money object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize Money',
        expectedType: 'Money',
      );
    }
  }

  @override
  Money deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'Money',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Failed to deserialize JSON',
        expectedType: 'Money',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Money instance, [
    SerializationConfig? config,
  ]) {
    return MoneyJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Money decode(dynamic json, [SerializationConfig? config]) {
    return MoneyJsonSerializer().fromJson(json, config);
  }
}
