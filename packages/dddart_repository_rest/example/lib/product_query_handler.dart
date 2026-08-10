import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest_example/product.dart';
import 'package:dddart_rest/dddart_rest.dart';

/// Server-side read contract for the Product price-range operation.
///
/// This is deliberately separate from base CRUD. Implementations own filtering,
/// stable ordering, pagination, and the pre-pagination total count.
abstract interface class ProductPriceRangeReadRepository
    implements Repository<Product> {
  /// Returns one inclusive price-range page and its pre-pagination total.
  Future<({List<Product> items, int totalCount})> findByPriceRangePage(
    double minPrice,
    double maxPrice, {
    required int skip,
    required int take,
  });
}

/// In-memory adapter used by the experiment server and behavioral tests.
class InMemoryProductReadRepository extends InMemoryRepository<Product>
    implements ProductPriceRangeReadRepository {
  @override
  Future<({List<Product> items, int totalCount})> findByPriceRangePage(
    double minPrice,
    double maxPrice, {
    required int skip,
    required int take,
  }) async {
    final matchingProducts = getAllSync()
        .where(
          (product) => product.price >= minPrice && product.price <= maxPrice,
        )
        .toList()
      ..sort((left, right) {
        final priceOrder = left.price.compareTo(right.price);
        if (priceOrder != 0) return priceOrder;

        final nameOrder = left.name.compareTo(right.name);
        return nameOrder != 0
            ? nameOrder
            : left.id.uuid.compareTo(right.id.uuid);
      });

    return (
      items: matchingProducts.skip(skip).take(take).toList(),
      totalCount: matchingProducts.length,
    );
  }
}

/// Handles product queries filtered by an inclusive price range.
Future<QueryResult<Product>> priceRangeQueryHandler(
  Repository<Product> repository,
  Map<String, String> queryParams,
  int skip,
  int take,
  dynamic authResult,
) async {
  final range = queryParams['priceRange'];
  if (range == null) {
    throw const FormatException(
      'Missing required "priceRange" query parameter.',
    );
  }

  final bounds = range.split(',');
  if (bounds.length != 2) {
    throw FormatException(
      'Invalid "priceRange" value "$range"; expected "<minPrice>,<maxPrice>".',
    );
  }

  final minPrice = double.tryParse(bounds[0]);
  final maxPrice = double.tryParse(bounds[1]);
  if (minPrice == null || maxPrice == null) {
    throw FormatException(
      'Invalid "priceRange" value "$range"; both bounds must be numbers.',
    );
  }
  if (!minPrice.isFinite || !maxPrice.isFinite) {
    throw FormatException(
      'Invalid "priceRange" value "$range"; both bounds must be finite.',
    );
  }
  if (minPrice > maxPrice) {
    throw FormatException(
      'Invalid "priceRange" value "$range"; the minimum must not exceed the maximum.',
    );
  }

  if (repository is! ProductPriceRangeReadRepository) {
    throw StateError(
      'The priceRange handler requires ProductPriceRangeReadRepository.',
    );
  }

  final page = await repository.findByPriceRangePage(
    minPrice,
    maxPrice,
    skip: skip,
    take: take,
  );

  return QueryResult<Product>(page.items, totalCount: page.totalCount);
}
