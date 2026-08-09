import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
// The generated repository part uses mongo_dart's public database types.
// ignore: unused_import
import 'package:mongo_dart/mongo_dart.dart';

part 'product.g.dart';

/// Example Product aggregate for additional examples.
@Serializable()
@GenerateMongoRepository(collectionName: 'products')
class Product extends AggregateRoot {
  /// Creates a new Product.
  Product({
    required this.name,
    required this.description,
    required this.price,
    required this.inStock,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Product name.
  final String name;

  /// Product description.
  final String description;

  /// Product price in cents.
  final int price;

  /// Whether the product is in stock.
  final bool inStock;

  /// Gets the price formatted as dollars.
  String get priceFormatted => '\$${(price / 100).toStringAsFixed(2)}';
}
