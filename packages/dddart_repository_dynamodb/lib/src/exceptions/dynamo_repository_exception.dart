/// Typed DynamoDB repository exception mapping.
library;

import 'dart:async';
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart/dddart.dart';
import 'package:http/http.dart' as http;

/// Converts SDK failures into the existing portable repository error contract.
class DynamoRepositoryException {
  /// Retained for compatibility with the original utility marker.
  const DynamoRepositoryException();

  /// Produces a safe message with no response values or raw exception cause.
  static RepositoryException map(Object error, String operation) {
    final type = switch (error) {
      ResourceNotFoundException() => RepositoryExceptionType.notFound,
      ConditionalCheckFailedException() => RepositoryExceptionType.duplicate,
      TimeoutException() => RepositoryExceptionType.timeout,
      http.ClientException() => RepositoryExceptionType.connection,
      RepositoryException(:final type) => type,
      _ => RepositoryExceptionType.unknown,
    };
    return RepositoryException('DynamoDB operation failed', type: type);
  }
}
