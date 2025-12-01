/// Shared test setup for Docker-based MySQL tests.
///
/// This file provides common setup and teardown logic for tests that
/// require a MySQL Docker container.
library;

import 'test_helpers.dart';

/// Sets up MySQL Docker container for all tests.
///
/// Call this in setUpAll() for test groups that need MySQL.
Future<void> setupMysqlContainer() async {
  await MysqlTestContainer.start();
}

/// Tears down MySQL Docker container after all tests.
///
/// Call this in tearDownAll() for test groups that need MySQL.
Future<void> teardownMysqlContainer() async {
  // Note: We typically don't stop the container between test runs
  // to speed up test execution. The container can be reused.
  // Uncomment the line below if you want to stop it after tests.
  // await MysqlTestContainer.stop();
}
