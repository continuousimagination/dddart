import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Test domain model
class TestProduct extends AggregateRoot {
  TestProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });
  final String name;
  final double price;
}

// Test serializer
class TestProductSerializer implements Serializer<TestProduct> {
  @override
  String serialize(TestProduct product, [dynamic config]) {
    return jsonEncode({
      'id': product.id.toString(),
      'name': product.name,
      'price': product.price,
      'createdAt': product.createdAt.toIso8601String(),
      'updatedAt': product.updatedAt.toIso8601String(),
    });
  }

  @override
  TestProduct deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return TestProduct(
      id: UuidValue.fromString(json['id'] as String),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

void main() {
  group('Optional Logging Behavior - HTTP', () {
    setUp(() {
      // Ensure no logging configuration exists
      Logger.root.clearListeners();
      Logger.root.level = Level.OFF;
    });

    test('CrudResource works without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Create a product
      final product = TestProduct(name: 'Test Product', price: 99.99);
      await repository.save(product);

      // Test GET request - should not crash
      final getRequest = Request(
        'GET',
        Uri.parse('http://localhost/products/${product.id}'),
        headers: {'accept': 'application/json'},
      );

      final getResponse =
          await resource.handleGetById(getRequest, product.id.toString());
      expect(getResponse.statusCode, equals(200));

      final responseBody = await getResponse.readAsString();
      final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
      expect(responseJson['name'], equals('Test Product'));
    });

    test('CrudResource handles POST without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final product = TestProduct(name: 'New Product', price: 49.99);
      final productData = {
        'id': product.id.toString(),
        'name': product.name,
        'price': product.price,
        'createdAt': product.createdAt.toIso8601String(),
        'updatedAt': product.updatedAt.toIso8601String(),
      };

      final postRequest = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: jsonEncode(productData),
        headers: {'content-type': 'application/json'},
      );

      final postResponse = await resource.handleCreate(postRequest);
      expect(postResponse.statusCode, equals(201));
    });

    test('CrudResource handles PUT without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Create initial product
      final product = TestProduct(name: 'Original', price: 10);
      await repository.save(product);

      final updatedData = {
        'id': product.id.toString(),
        'name': 'Updated',
        'price': 20.0,
        'createdAt': product.createdAt.toIso8601String(),
        'updatedAt': product.updatedAt.toIso8601String(),
      };

      final putRequest = Request(
        'PUT',
        Uri.parse('http://localhost/products/${product.id}'),
        body: jsonEncode(updatedData),
        headers: {'content-type': 'application/json'},
      );

      final putResponse =
          await resource.handleUpdate(putRequest, product.id.toString());
      expect(putResponse.statusCode, equals(200));
    });

    test('CrudResource handles DELETE without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Create product
      final product = TestProduct(name: 'To Delete', price: 5);
      await repository.save(product);

      final deleteRequest = Request(
        'DELETE',
        Uri.parse('http://localhost/products/${product.id}'),
      );

      final deleteResponse =
          await resource.handleDelete(deleteRequest, product.id.toString());
      expect(deleteResponse.statusCode, equals(204));
    });

    test('CrudResource handles errors without logging configuration', () async {
      // Requirement 4.1, 4.2, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Try to get non-existent product
      final nonExistentId = UuidValue.generate();
      final getRequest = Request(
        'GET',
        Uri.parse('http://localhost/products/$nonExistentId'),
        headers: {'accept': 'application/json'},
      );

      final response =
          await resource.handleGetById(getRequest, nonExistentId.toString());
      expect(response.statusCode, equals(404));
    });

    test('Multiple HTTP operations work without logging', () async {
      // Requirement 4.1, 4.2, 4.3, 4.4, 4.5
      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      // Perform multiple operations
      for (var i = 0; i < 10; i++) {
        final product = TestProduct(name: 'Product $i', price: i * 10.0);
        await repository.save(product);

        final getRequest = Request(
          'GET',
          Uri.parse('http://localhost/products/${product.id}'),
          headers: {'accept': 'application/json'},
        );

        final response =
            await resource.handleGetById(getRequest, product.id.toString());
        expect(response.statusCode, equals(200));
      }
    });

    test('CrudResource works when Logger.root.level is OFF', () async {
      // Requirement 4.1, 4.2, 4.3
      Logger.root.level = Level.OFF;

      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final product = TestProduct(name: 'Test', price: 100);
      await repository.save(product);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/products/${product.id}'),
        headers: {'accept': 'application/json'},
      );

      final response =
          await resource.handleGetById(request, product.id.toString());
      expect(response.statusCode, equals(200));
    });

    test('CrudResource works when no handlers are attached', () async {
      // Requirement 4.1, 4.3
      Logger.root.level = Level.ALL;
      Logger.root.clearListeners();

      final repository = InMemoryRepository<TestProduct>();
      final serializer = TestProductSerializer();
      final resource = CrudResource<TestProduct>(
        path: 'products',
        repository: repository,
        serializers: {'application/json': serializer},
      );

      final product = TestProduct(name: 'Test', price: 100);
      await repository.save(product);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/products/${product.id}'),
        headers: {'accept': 'application/json'},
      );

      final response =
          await resource.handleGetById(request, product.id.toString());
      expect(response.statusCode, equals(200));
    });
  });
}
