import 'dart:io';

import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_repository_rest_example/product.dart';
import 'package:dddart_repository_rest_example/product_query_handler.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  test(
    'findByPriceRange includes both boundaries and excludes outsiders',
    () async {
      final port = await _findAvailablePort();
      final serverRepository = InMemoryProductReadRepository();
      final seededProducts = [
        Product(
          name: 'Below lower bound',
          description: 'Must not be returned.',
          price: 9.99,
          category: 'test',
        ),
        Product(
          name: 'At lower bound',
          description: 'Must be returned.',
          price: 10,
          category: 'test',
        ),
        Product(
          name: 'Inside range',
          description: 'Must be returned.',
          price: 15,
          category: 'test',
        ),
        Product(
          name: 'At upper bound',
          description: 'Must be returned.',
          price: 20,
          category: 'test',
        ),
        Product(
          name: 'Above upper bound',
          description: 'Must not be returned.',
          price: 20.01,
          category: 'test',
        ),
      ];

      for (final product in seededProducts) {
        await serverRepository.save(product);
      }

      final productResource = CrudResource<Product, void>(
        path: '/products',
        repository: serverRepository,
        serializer: ProductJsonSerializer(),
        queryHandlers: {'priceRange': priceRangeQueryHandler},
      );
      final server = HttpServer(port: port);
      server.registerResource(productResource);

      RestConnection? connection;
      var serverStarted = false;
      try {
        await server.start();
        serverStarted = true;

        connection = RestConnection(baseUrl: 'http://127.0.0.1:$port');
        final clientRepository = ProductRestRepository(connection);

        final results = await clientRepository.findByPriceRange(10, 20);
        final resultNames = results.map((product) => product.name);

        expect(
          resultNames,
          unorderedEquals(['At lower bound', 'Inside range', 'At upper bound']),
        );
        expect(resultNames, isNot(contains('Below lower bound')));
        expect(resultNames, isNot(contains('Above upper bound')));
      } finally {
        connection?.dispose();
        if (serverStarted) {
          await server.stop();
        }
      }
    },
  );
}

Future<int> _findAvailablePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
