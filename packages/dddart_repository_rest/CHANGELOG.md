# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-02

### Added

- Initial release of dddart_repository_rest
- Code generation for REST API-backed repositories
- `@GenerateRestRepository` annotation for aggregate roots
- `RestConnection` class for managing HTTP client and authentication
- Integration with dddart_rest_client for automatic authentication
- Support for custom repository interfaces with domain-specific queries
- Comprehensive HTTP status code to RepositoryException mapping
- Generated repositories support CRUD operations (getById, save, deleteById)
- Automatic JSON serialization using dddart_json serializers
- Support for both authenticated and unauthenticated REST connections
