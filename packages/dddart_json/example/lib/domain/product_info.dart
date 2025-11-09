import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';

part 'product_info.g.dart';

/// Value object containing product information for order items.
@Serializable()
class ProductInfo extends Value {
  const ProductInfo({
    required this.name,
    required this.sku,
    required this.category,
    this.description,
  });

  final String name;
  final String sku;
  final String category;
  final String? description;

  @override
  List<Object?> get props => [name, sku, category, description];

  @override
  String toString() => '$name ($sku)';

  /// Get a display name for the product
  String get displayName => description != null ? '$name - $description' : name;

  /// Check if this is an electronic product
  bool get isElectronic => category.toLowerCase().contains('electronic');

  /// Get a short identifier for the product
  String get shortId => sku.split('-').first;
}
