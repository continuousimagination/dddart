@Tags(['requires-mysql'])
library;

import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:test/test.dart';

import '../../dddart_repository_sql/test/transaction_ownership_contract.dart';

void main() => transactionOwnershipContract(
      () => MysqlConnection(
        host: 'localhost',
        port: 3307,
        database: 'test_db',
        user: 'root',
        password: 'test_password',
      ),
    );
