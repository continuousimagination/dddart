# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-04

### Changed

- **BREAKING**: Migrated from `mysql1` driver to `mysql_client` driver
- **BREAKING**: Minimum MySQL version is now 5.7+ (MySQL 8.0+ recommended)
- Improved MySQL 8.0+ authentication support with native `caching_sha2_password` plugin
- Enhanced connection stability and error handling
- Updated error mapping to handle `mysql_client` exception types
- Improved transaction handling using `mysql_client`'s transactional API

### Fixed

- Fixed 27 integration test failures related to MySQL 8.0 compatibility
- Fixed SocketException errors when connecting to MySQL 8.0 with default authentication
- Fixed "packets out of order" errors under concurrent query load
- Fixed type cast errors with Set and List collection deserialization
- Fixed entity relationship loading issues in complex object graphs
- Fixed connection stability issues with long-running transactions
- Fixed intermittent connection drops due to authentication issues

### Removed

- Removed dependency on `mysql1` package (replaced with `mysql_client`)
- Removed need for `mysql_native_password` legacy authentication workarounds

### Migration Guide

**For most users, upgrading is straightforward:**

1. Update your `pubspec.yaml`:
   ```yaml
   dependencies:
     dddart_repository_mysql: ^2.0.0  # Update from ^0.9.0
   ```

2. Run `dart pub get`

3. Test your application - no code changes should be required

**If you were using MySQL 8.0 workarounds:**

You can now remove the legacy authentication workaround:
```sql
-- Remove this workaround (no longer needed):
-- ALTER USER 'user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';

-- MySQL 8.0 default authentication now works:
CREATE USER 'user'@'%' IDENTIFIED BY 'password';
```

**What stays the same:**
- All public APIs remain unchanged
- Generated repository code is compatible (no regeneration needed)
- SQL generation produces identical output
- Transaction semantics are identical
- Error handling patterns are the same

**Custom repository implementations:**

If you have custom implementations that directly import `mysql1`, you may need to update those imports to `mysql_client`. Check your custom code for direct driver usage.

**Need help?** See the [README](README.md) for detailed migration instructions and troubleshooting.

## [0.9.0] - 2024-12-01

### Added

- Initial release of dddart_repository_mysql
- MysqlConnection implementation with connection pooling
- MysqlDialect with MySQL-specific SQL syntax and type mappings
- MysqlRepositoryGenerator for automatic repository code generation
- @GenerateMysqlRepository annotation
- Support for value object embedding with prefixed columns
- Transaction support with nested transaction handling
- Comprehensive error mapping to RepositoryException types
- Custom repository interface support
- Automatic schema generation with InnoDB and utf8mb4
- UUID encoding/decoding to BINARY(16)
- DateTime encoding/decoding to TIMESTAMP
- Foreign key constraints with CASCADE DELETE
- Docker-based test infrastructure
- Comprehensive examples and documentation
