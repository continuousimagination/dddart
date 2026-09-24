import 'dart:io';

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';

/// MySQL host used by the runnable examples.
String get mysqlExampleHost =>
    Platform.environment['MYSQL_HOST'] ?? '127.0.0.1';

/// MySQL port used by the runnable examples.
int get mysqlExamplePort =>
    int.parse(Platform.environment['MYSQL_PORT'] ?? '3306');

/// Creates a connection from the shared local/CI environment contract.
MysqlConnection createMysqlExampleConnection({int? port}) {
  return MysqlConnection(
    host: mysqlExampleHost,
    port: port ?? mysqlExamplePort,
    database: Platform.environment['MYSQL_DATABASE'] ?? 'dddart_example',
    user: Platform.environment['MYSQL_USER'] ?? 'root',
    password: Platform.environment['MYSQL_PASSWORD'] ?? 'password',
  );
}
