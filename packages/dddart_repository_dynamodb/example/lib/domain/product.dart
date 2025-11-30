/// Product aggregate for examples.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'product.g.dart';

/// Product aggregate demonstrating DynamoDB repository usage.
@Serializable()
@GenerateDynamoRepository(tableName: 'products')
class Product extends AggregateRoot {
  /// Creates a product.
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

  /// Product price.
  final double price;

  /// Whether the product is in stock.
  final bool inStock;
}
