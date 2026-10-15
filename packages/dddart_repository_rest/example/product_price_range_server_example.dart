/// End-to-end server example for querying products by an inclusive price range.
library;

import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_repository_rest_example/product.dart';
import 'package:dddart_repository_rest_example/product_query_handler.dart';

Future<void> main() async {
  final repository = InMemoryProductReadRepository();

  for (final product in [
    Product(
      name: 'Pocket Notebook',
      description: 'A compact notebook for everyday notes.',
      price: 10,
      category: 'stationery',
    ),
    Product(
      name: 'Coffee Maker',
      description: 'A programmable coffee maker for the kitchen.',
      price: 75,
      category: 'appliances',
    ),
    Product(
      name: 'Wireless Headphones',
      description: 'Over-ear headphones with active noise cancellation.',
      price: 150,
      category: 'electronics',
    ),
    Product(
      name: 'Ergonomic Desk Chair',
      description: 'An adjustable chair with lumbar support.',
      price: 250,
      category: 'furniture',
    ),
    Product(
      name: 'Ultrabook',
      description: 'A lightweight laptop for work and travel.',
      price: 1200,
      category: 'electronics',
    ),
  ]) {
    await repository.save(product);
  }

  final productResource = CrudResource<Product, void>(
    path: '/products',
    repository: repository,
    serializer: ProductJsonSerializer(),
    queryHandlers: {'priceRange': priceRangeQueryHandler},
  );

  // Keep the port explicit so the example's wire contract is visible.
  // ignore: avoid_redundant_argument_values
  final server = HttpServer(port: 8080);
  server.registerResource(productResource);
  await server.start();

  print('Product server running at http://localhost:8080');
  print(
    'Try: GET http://localhost:8080/products?priceRange=75,250&skip=0&take=10',
  );
  print('Price-range bounds are inclusive; skip and take are optional.');
}
