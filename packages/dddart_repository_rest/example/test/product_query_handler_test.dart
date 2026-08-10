import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest_example/product.dart';
import 'package:dddart_repository_rest_example/product_query_handler.dart';
import 'package:test/test.dart';

void main() {
  group('priceRangeQueryHandler', () {
    late InMemoryProductReadRepository repository;

    setUp(() async {
      repository = InMemoryProductReadRepository();
      for (final product in [
        _product('Below', 9.99),
        _product('Lower boundary', 10),
        _product('Middle', 15),
        _product('Upper boundary', 20),
        _product('Above', 20.01),
      ]) {
        await repository.save(product);
      }
    });

    test(
      'filters inclusively before pagination and reports the full count',
      () async {
        final result = await priceRangeQueryHandler(
          repository,
          {'priceRange': '10,20'},
          1,
          1,
          null,
        );

        expect(result.totalCount, 3);
        expect(result.items.map((product) => product.name), ['Middle']);
      },
    );

    test('orders by price, name, and ID before pagination', () async {
      final unorderedRepository = InMemoryProductReadRepository();
      for (final product in [
        _product('Zulu', 15, id: _uuid(4)),
        _product('Alpha', 15, id: _uuid(3)),
        _product('Lower', 10, id: _uuid(2)),
        _product('Alpha', 15, id: _uuid(1)),
      ]) {
        await unorderedRepository.save(product);
      }

      final result = await priceRangeQueryHandler(
        unorderedRepository,
        {'priceRange': '10,20'},
        1,
        2,
        null,
      );

      expect(result.totalCount, 4);
      expect(
        result.items.map((product) => product.id.uuid),
        [_uuid(1), _uuid(3)],
      );
    });

    final invalidRanges = <String, Map<String, String>>{
      'missing': {},
      'missing bound': {'priceRange': '10'},
      'non-numeric': {'priceRange': 'ten,20'},
      'non-finite': {'priceRange': 'NaN,20'},
      'reversed': {'priceRange': '20,10'},
    };

    for (final invalidRange in invalidRanges.entries) {
      test('rejects ${invalidRange.key} input', () {
        expect(
          priceRangeQueryHandler(repository, invalidRange.value, 0, 50, null),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('rejects a repository without the explicit read contract', () {
      expect(
        priceRangeQueryHandler(
          InMemoryRepository<Product>(),
          {'priceRange': '10,20'},
          0,
          50,
          null,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Product _product(String name, double price, {String? id}) {
  return Product(
    name: name,
    description: '$name product',
    price: price,
    category: 'test',
    id: id == null ? null : UuidValue.fromString(id),
  );
}

String _uuid(int suffix) =>
    '00000000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}';
