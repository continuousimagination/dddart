# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
