// ignore_for_file: deprecated_member_use_from_same_package

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

void main() {
  test('legacy maxConnections remains accepted without changing lifecycle', () {
    final connection = MysqlConnection(
      host: 'localhost',
      port: 3306,
      database: 'test_db',
      user: 'root',
      password: 'test_password',
      maxConnections: 17,
    );

    expect(connection.maxConnections, equals(17));
    expect(connection.isOpen, isFalse);
  });
}
