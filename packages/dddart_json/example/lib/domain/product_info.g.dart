// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_info.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class ProductInfoJsonSerializer implements JsonSerializer<ProductInfo> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  ProductInfoJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    ProductInfo instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'category',
        effectiveConfig.fieldRename,
      ): instance.category,
      if (instance.description != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'description',
          effectiveConfig.fieldRename,
        ): instance.description,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('sku', effectiveConfig.fieldRename):
          instance.sku,
    };
    return json;
  }

  @override
  ProductInfo fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize ProductInfo from null JSON',
        expectedType: 'ProductInfo',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'ProductInfo',
      );
    }
    try {
      return ProductInfo(
        category:
            json[SerializationUtils.applyFieldRename(
                  'category',
                  effectiveConfig.fieldRename,
                )]
                as String,
        description:
            json[SerializationUtils.applyFieldRename(
                  'description',
                  effectiveConfig.fieldRename,
                )]
                as String?,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        sku:
            json[SerializationUtils.applyFieldRename(
                  'sku',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize ProductInfo: $e',
        expectedType: 'ProductInfo',
      );
    }
  }

  @override
  String serialize(ProductInfo object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  ProductInfo deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'ProductInfo',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    ProductInfo instance, [
    SerializationConfig? config,
  ]) {
    return ProductInfoJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static ProductInfo decode(dynamic json, [SerializationConfig? config]) {
    return ProductInfoJsonSerializer().fromJson(json, config);
  }
}
