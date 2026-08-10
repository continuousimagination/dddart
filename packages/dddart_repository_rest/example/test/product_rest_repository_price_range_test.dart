import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_repository_rest_example/product.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'findByPriceRange sends the frozen single-key query and decodes JSON',
    () async {
      late http.Request capturedRequest;
      final expected = Product(
        name: 'Middle',
        description: 'Inside the requested range.',
        price: 15,
        category: 'test',
      );
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([ProductJsonSerializer().toJson(expected)]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final connection = RestConnection(
        baseUrl: 'https://example.test',
        httpClient: client,
      );
      addTearDown(connection.dispose);

      final results = await ProductRestRepository(
        connection,
      ).findByPriceRange(10, 20);

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/products');
      expect(capturedRequest.url.queryParameters, {'priceRange': '10.0,20.0'});
      expect(capturedRequest.url.query, 'priceRange=10.0%2C20.0');
      expect(capturedRequest.url.queryParameters, hasLength(1));
      expect(results, hasLength(1));
      expect(results.single.name, expected.name);
      expect(results.single.price, expected.price);
    },
  );

  test(
    'findByPriceRange maps non-success responses through repository errors',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Price query denied'}),
          403,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      final connection = RestConnection(
        baseUrl: 'https://example.test',
        httpClient: client,
      );
      addTearDown(connection.dispose);

      expect(
        ProductRestRepository(connection).findByPriceRange(10, 20),
        throwsA(
          isA<RepositoryException>()
              .having(
                (error) => error.type,
                'type',
                RepositoryExceptionType.forbidden,
              )
              .having(
                (error) => error.message,
                'message',
                'Price query denied',
              ),
        ),
      );
    },
  );
}
