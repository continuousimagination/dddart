import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';

/// Creates [tableName] when absent and waits until it is ready for traffic.
///
/// The generated repository owns the table schema through [createTable]. This
/// helper only makes that public operation idempotent for runnable examples.
Future<void> ensureDynamoTable({
  required DynamoConnection connection,
  required String tableName,
  required Future<void> Function() createTable,
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
      if (response.table?.tableStatus == TableStatus.active) return;
    } on ResourceNotFoundException {
      // DynamoDB can briefly hide a table while creation propagates.
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('DynamoDB table $tableName did not become active in time');
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
