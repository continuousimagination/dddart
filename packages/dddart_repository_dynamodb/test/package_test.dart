import 'dart:io';

import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:test/test.dart';

void main() {
  group('Package Setup', () {
    test('should export GenerateDynamoRepository annotation', () {
      const annotation = GenerateDynamoRepository();
      expect(annotation, isNotNull);
      expect(annotation.tableName, isNull);
      expect(annotation.implements, isNull);
    });

    test('should export GenerateDynamoRepository with parameters', () {
      const annotation = GenerateDynamoRepository(
        tableName: 'test_table',
      );
      expect(annotation.tableName, equals('test_table'));
    });

    test('should export DynamoConnection class', () {
      expect(DynamoConnection, isNotNull);
    });

    test('should export AttributeValueConverter class', () {
      expect(AttributeValueConverter, isNotNull);
    });

    test('should export DynamoRepositoryException class', () {
      expect(DynamoRepositoryException, isNotNull);
    });

    test('should link package metadata to the canonical repository', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        pubspec,
        contains('repository: https://github.com/continuousimagination/dddart'),
      );
      expect(pubspec, isNot(contains('yourusername')));
    });
  });
}
