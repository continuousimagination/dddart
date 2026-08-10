import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

/// Creates [tableName] when absent and waits until it is ready for traffic.
///
/// The supplied [createTable] callback owns the table and index schema. This
/// helper makes that operation idempotent for runnable examples and can verify
/// that required global secondary indexes are ready.
Future<void> ensureDynamoTable({
  required DynamoConnection connection,
  required String tableName,
  required Future<void> Function() createTable,
  Set<String> requiredGlobalSecondaryIndexes = const {},
}) async {
  if (!await _tableExists(connection, tableName)) {
    try {
      await createTable();
    } on RepositoryException {
      // A concurrent example may have created the table after our preflight.
      // Verify the postcondition instead of depending on mapped error text.
      if (!await _tableExists(connection, tableName)) rethrow;
    }
  }

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await connection.client.describeTable(
        tableName: tableName,
      );
      final table = response.table;
      final activeIndexes = <String>{
        for (final index in table?.globalSecondaryIndexes ?? const [])
          if (index.indexName != null &&
              index.indexStatus == IndexStatus.active)
            index.indexName!,
      };
      if (table?.tableStatus == TableStatus.active &&
          activeIndexes.containsAll(requiredGlobalSecondaryIndexes)) {
        return;
      }
    } on ResourceNotFoundException {
      // DynamoDB can briefly hide a table while creation propagates.
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'DynamoDB table $tableName and its required indexes '
    '$requiredGlobalSecondaryIndexes did not become active in time',
  );
}

Future<bool> _tableExists(
  DynamoConnection connection,
  String tableName,
) async {
  try {
    await connection.client.describeTable(tableName: tableName);
    return true;
  } on ResourceNotFoundException {
    return false;
  }
}
