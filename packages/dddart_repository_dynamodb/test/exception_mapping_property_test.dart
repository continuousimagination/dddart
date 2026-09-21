/// Uses the production typed mapper; no copied string-matching implementation.
@Tags(['property-test'])
library;

import 'dart:async';
import 'dart:math';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final random = Random(42);
  final cases =
      <
        ({
          String name,
          Object Function(String) error,
          RepositoryExceptionType type,
        })
      >[
        (
          name: 'ResourceNotFoundException',
          error: (message) => ResourceNotFoundException(message: message),
          type: RepositoryExceptionType.notFound,
        ),
        (
          name: 'ConditionalCheckFailedException',
          error: (message) => ConditionalCheckFailedException(message: message),
          type: RepositoryExceptionType.duplicate,
        ),
        (
          name: 'connection',
          error: http.ClientException.new,
          type: RepositoryExceptionType.connection,
        ),
        (
          name: 'timeout',
          error: TimeoutException.new,
          type: RepositoryExceptionType.timeout,
        ),
        (
          name: 'unknown',
          error: StateError.new,
          type: RepositoryExceptionType.unknown,
        ),
        (
          name: 'typed rejection',
          error: (message) => RepositoryException(
            message,
            type: RepositoryExceptionType.constraint,
          ),
          type: RepositoryExceptionType.constraint,
        ),
      ];
  for (final entry in cases) {
    test(
      '${entry.name} retains its typed meaning for100synthetic failures',
      () {
        for (var i = 0; i < 100; i++) {
          final marker = 'restricted-${random.nextInt(1 << 30)}-$i';
          final mapped = DynamoRepositoryException.map(
            entry.error(marker),
            'operation',
          );
          expect(mapped.type, entry.type);
          expect(mapped.message, 'DynamoDB operation failed');
          expect(mapped.toString(), isNot(contains(marker)));
          expect(mapped.cause, isNull);
        }
      },
    );
  }
  test('exception text cannot impersonate SDK/network exception types', () {
    final mapped = DynamoRepositoryException.map(
      StateError('ResourceNotFoundException network timeout'),
      'save',
    );
    expect(mapped.type, RepositoryExceptionType.unknown);
    expect(mapped.cause, isNull);
  });
  test('all random mappings suppress original causes and operation text', () {
    for (var i = 0; i < 100; i++) {
      final entry = cases[random.nextInt(cases.length)];
      final marker = 'restricted-${random.nextInt(1 << 30)}';
      final mapped = DynamoRepositoryException.map(entry.error(marker), marker);
      expect(mapped.type, entry.type);
      expect(mapped.cause, isNull);
      expect(mapped.toString(), isNot(contains(marker)));
    }
  });
}
