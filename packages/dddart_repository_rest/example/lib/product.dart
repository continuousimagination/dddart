/// Example domain model for a Product aggregate.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'product.g.dart';

/// Custom repository interface with domain-specific query methods.
abstract interface class ProductRepository implements Repository<Product> {
  /// Finds products by category.
  Future<List<Product>> findByCategory(String category);

  /// Finds the first default REST page of products within a price range.
  Future<List<Product>> findByPriceRange(double minPrice, double maxPrice);
}

/// Product aggregate root representing a product in the system.
@Serializable()
@GenerateRestRepository(
  resourcePath: '/products',
  implements: ProductRepository,
)
class Product extends AggregateRoot {
  /// Creates a new product.
  Product({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
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

  /// Product category.
  final String category;
}

/// Custom implementation of ProductRepository with domain-specific queries.
///
/// This class extends the generated ProductRestRepositoryBase and implements
/// the custom query methods defined in the ProductRepository interface.
///
/// Since this class shares the generated part's Dart library, it can use the
/// library-private connection, serializer, path, and error-mapping helpers.
class ProductRestRepository extends ProductRestRepositoryBase {
  /// Creates a custom product repository.
  ProductRestRepository(super.connection);

  @override
  Future<List<Product>> findByCategory(String category) async {
    try {
      final response = await _connection.executeRequest(
        () => _connection.client.get(
          Uri.parse('${_connection.baseUrl}$_resourcePath?category=$category'),
        ),
        operation: 'find products by category',
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;

        // Use the generated library-private serializer helper.
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Use the generated error mapper for consistent repository failures.
      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find products by category: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }

  @override
  Future<List<Product>> findByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    try {
      final uri = Uri.parse(
        '${_connection.baseUrl}$_resourcePath',
      ).replace(queryParameters: {'priceRange': '$minPrice,$maxPrice'});
      final response = await _connection.executeRequest(
        () => _connection.client.get(uri),
        operation: 'find products by price range',
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw _mapHttpException(response.statusCode, response.body);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        'Failed to find products by price range: $e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }
}
