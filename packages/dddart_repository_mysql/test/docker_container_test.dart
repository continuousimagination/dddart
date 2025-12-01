/// Integration tests for Docker container management.
@Tags(['requires-mysql', 'integration'])
library;

import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('MysqlTestContainer', () {
    test('should check if Docker is available', () async {
      final available = await MysqlTestContainer.isDockerAvailable();

      // This test assumes Docker is installed
      // If Docker is not available, other tests will be skipped
      expect(
        available,
        isTrue,
        reason: 'Docker must be installed to run tests',
      );
    });

    test('should start MySQL container', () async {
      // Start the container
      await MysqlTestContainer.start();

      // Verify container is running
      final running = await MysqlTestContainer.isRunning();
      expect(running, isTrue);
    });

    test('should be idempotent when starting already running container',
        () async {
      // Start container first time
      await MysqlTestContainer.start();

      // Start again - should not fail
      await MysqlTestContainer.start();

      // Verify still running
      final running = await MysqlTestContainer.isRunning();
      expect(running, isTrue);
    });

    test('should detect MySQL readiness', () async {
      // Start container
      await MysqlTestContainer.start();

      // Create connection
      final connection = MysqlTestContainer.createConnection();

      // Should be able to open connection
      await connection.open();
      expect(connection.isOpen, isTrue);

      // Clean up
      await connection.close();
    });

    test('should create working test connection', () async {
      // Start container
      await MysqlTestContainer.start();

      // Create connection
      final connection = MysqlTestContainer.createConnection();
      await connection.open();

      // Execute a simple query to verify connection works
      final result = await connection.query('SELECT 1 as value');
      expect(result, hasLength(1));
      expect(result.first['value'], equals(1));

      // Clean up
      await connection.close();
    });

    test('should stop and remove container', () async {
      // Start container first
      await MysqlTestContainer.start();
      expect(await MysqlTestContainer.isRunning(), isTrue);

      // Stop container
      await MysqlTestContainer.stop();

      // Verify container is not running
      final running = await MysqlTestContainer.isRunning();
      expect(running, isFalse);
    });
  });

  group('TestMysqlHelper', () {
    late TestMysqlHelper helper;

    setUpAll(() async {
      // Ensure container is running
      await MysqlTestContainer.start();
    });

    setUp(() async {
      helper = createTestHelper();
      // Connect and clean up any existing tables
      await helper.connect();
      await helper.dropAllTables();
    });

    tearDown(() async {
      if (helper.isConnected) {
        await helper.dropAllTables();
        await helper.disconnect();
      }
    });

    test('should connect to MySQL', () async {
      final connection = await helper.connect();

      expect(connection.isOpen, isTrue);
      expect(helper.isConnected, isTrue);
    });

    test('should disconnect from MySQL', () async {
      await helper.connect();
      expect(helper.isConnected, isTrue);

      await helper.disconnect();
      expect(helper.isConnected, isFalse);
    });

    test('should create and detect tables', () async {
      await helper.connect();

      // Create a test table
      await helper.connection.execute('''
        CREATE TABLE test_table (
          id VARCHAR(36) PRIMARY KEY,
          name VARCHAR(255)
        )
      ''');

      // Check table exists
      final exists = await helper.tableExists('test_table');
      expect(exists, isTrue);

      // Check non-existent table
      final notExists = await helper.tableExists('non_existent');
      expect(notExists, isFalse);
    });

    test('should list tables', () async {
      await helper.connect();

      // Create test tables
      await helper.connection.execute('''
        CREATE TABLE table1 (id VARCHAR(36) PRIMARY KEY)
      ''');
      await helper.connection.execute('''
        CREATE TABLE table2 (id VARCHAR(36) PRIMARY KEY)
      ''');

      // List tables
      final tables = await helper.listTables();
      expect(tables, contains('table1'));
      expect(tables, contains('table2'));
    });

    test('should count rows in table', () async {
      await helper.connect();

      // Create and populate test table
      await helper.connection.execute('''
        CREATE TABLE test_table (
          id VARCHAR(36) PRIMARY KEY,
          name VARCHAR(255)
        )
      ''');

      await helper.connection
          .execute("INSERT INTO test_table (id, name) VALUES ('1', 'test1')");
      await helper.connection
          .execute("INSERT INTO test_table (id, name) VALUES ('2', 'test2')");

      // Count rows
      final count = await helper.countRows('test_table');
      expect(count, equals(2));
    });

    test('should clear table data', () async {
      await helper.connect();

      // Create and populate test table
      await helper.connection.execute('''
        CREATE TABLE test_table (
          id VARCHAR(36) PRIMARY KEY,
          name VARCHAR(255)
        )
      ''');

      await helper.connection
          .execute("INSERT INTO test_table (id, name) VALUES ('1', 'test1')");
      await helper.connection
          .execute("INSERT INTO test_table (id, name) VALUES ('2', 'test2')");

      expect(await helper.countRows('test_table'), equals(2));

      // Clear table
      await helper.clearTable('test_table');

      // Verify empty
      expect(await helper.countRows('test_table'), equals(0));

      // Verify table still exists
      expect(await helper.tableExists('test_table'), isTrue);
    });

    test('should drop all tables', () async {
      await helper.connect();

      // Create test tables with foreign keys
      await helper.connection.execute('''
        CREATE TABLE parent_table (
          id VARCHAR(36) PRIMARY KEY,
          name VARCHAR(255)
        ) ENGINE=InnoDB
      ''');

      await helper.connection.execute('''
        CREATE TABLE child_table (
          id VARCHAR(36) PRIMARY KEY,
          parent_id VARCHAR(36),
          name VARCHAR(255),
          FOREIGN KEY (parent_id) REFERENCES parent_table(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
      ''');

      // Verify tables exist
      expect(await helper.tableExists('parent_table'), isTrue);
      expect(await helper.tableExists('child_table'), isTrue);

      // Drop all tables
      await helper.dropAllTables();

      // Verify tables are gone
      expect(await helper.tableExists('parent_table'), isFalse);
      expect(await helper.tableExists('child_table'), isFalse);
    });

    test('should handle foreign key constraints when dropping tables',
        () async {
      await helper.connect();

      // Create tables with circular foreign keys
      await helper.connection.execute('''
        CREATE TABLE table_a (
          id VARCHAR(36) PRIMARY KEY,
          b_id VARCHAR(36)
        ) ENGINE=InnoDB
      ''');

      await helper.connection.execute('''
        CREATE TABLE table_b (
          id VARCHAR(36) PRIMARY KEY,
          a_id VARCHAR(36),
          FOREIGN KEY (a_id) REFERENCES table_a(id)
        ) ENGINE=InnoDB
      ''');

      await helper.connection.execute('''
        ALTER TABLE table_a
        ADD FOREIGN KEY (b_id) REFERENCES table_b(id)
      ''');

      // Should be able to drop all tables despite foreign keys
      await helper.dropAllTables();

      expect(await helper.tableExists('table_a'), isFalse);
      expect(await helper.tableExists('table_b'), isFalse);
    });
  });

  group('withMysqlConnection helper', () {
    setUpAll(() async {
      await MysqlTestContainer.start();
    });

    test('should provide connection and clean up', () async {
      var connectionWasOpen = false;

      await withMysqlConnection((connection) async {
        connectionWasOpen = connection.isOpen;

        // Create a test table
        await connection.execute('''
          CREATE TABLE test_table (id VARCHAR(36) PRIMARY KEY)
        ''');
      });

      expect(connectionWasOpen, isTrue);

      // Verify connection was cleaned up
      final helper = createTestHelper();
      await helper.connect();
      final tables = await helper.listTables();
      await helper.disconnect();

      // Table should not exist (cleaned up)
      expect(tables, isEmpty);
    });

    test('should clear specified tables', () async {
      // Create and populate a table
      final helper = createTestHelper();
      await helper.connect();

      await helper.connection.execute('''
        CREATE TABLE test_table (
          id VARCHAR(36) PRIMARY KEY,
          name VARCHAR(255)
        )
      ''');

      await helper.connection
          .execute("INSERT INTO test_table (id, name) VALUES ('1', 'test')");

      await helper.disconnect();

      // Use withMysqlConnection with clearTables
      await withMysqlConnection(
        (connection) async {
          final result = await connection.query('SELECT * FROM test_table');
          expect(result, isEmpty);
        },
        clearTables: ['test_table'],
      );
    });
  });
}
