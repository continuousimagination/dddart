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

  /// Finds products within a price range.
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
/// Since this is in the same library as the generated code, it has access
/// to the protected members (_connection, _serializer, _resourcePath, _mapHttpException).
class ProductRestRepository extends ProductRestRepositoryBase {
  /// Creates a custom product repository.
  ProductRestRepository(super.connection);

  @override
  Future<List<Product>> findByCategory(String category) async {
    try {
      // Use the protected _connection member to make custom HTTP requests
      final response = await _connection.httpClient.get(
        Uri.parse('${_connection.baseUrl}$_resourcePath?category=$category'),
      );

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;

        // Use the protected _serializer member to deserialize responses
        return jsonList
            .map((json) => _serializer.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Use the protected _mapHttpException helper for consistent error handling
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
      // Build query string with multiple parameters
      final response = await _connection.httpClient.get(
        Uri.parse(
          '${_connection.baseUrl}$_resourcePath?minPrice=$minPrice&maxPrice=$maxPrice',
        ),
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
