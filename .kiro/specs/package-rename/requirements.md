# Requirements Document: Package Rename from dddart_http to dddart_rest

## Introduction

Rename the `dddart_http` package to `dddart_rest` to better reflect its specific purpose of providing RESTful CRUD APIs for DDD aggregate roots, distinguishing it from the more general HTTP concerns handled by `dddart_webhooks`.

## Glossary

- **dddart_http**: The current package name for the HTTP CRUD API framework
- **dddart_rest**: The proposed new package name that better conveys the CRUD/REST focus
- **Package Name**: The identifier used in pubspec.yaml and import statements
- **Directory Name**: The folder name under packages/
- **Library Name**: The name used in the library directive
- **Import Path**: The package reference used in import statements (e.g., `package:dddart_rest/dddart_rest.dart`)

## Requirements

### Requirement 1: Package Identity

**User Story:** As a developer, I want the package name to clearly indicate its purpose, so that I understand it's for REST CRUD APIs and not general HTTP handling.

#### Acceptance Criteria

1. THE package name SHALL be changed from `dddart_http` to `dddart_rest`
2. THE package description SHALL clearly state it provides RESTful CRUD endpoints for aggregate roots
3. THE new name SHALL distinguish the package from `dddart_webhooks` which handles incoming webhooks

### Requirement 2: File System Changes

**User Story:** As a developer working with the codebase, I want the directory structure to reflect the new package name, so that the file system organization is consistent.

#### Acceptance Criteria

1. THE directory `packages/dddart_http` SHALL be renamed to `packages/dddart_rest`
2. THE main library file `lib/dddart_http.dart` SHALL be renamed to `lib/dddart_rest.dart`
3. THE example directory `packages/dddart_rest/example` SHALL have its pubspec.yaml name updated to `dddart_rest_example`
4. ALL file paths in documentation SHALL reference the new directory name

### Requirement 3: Package Metadata Updates

**User Story:** As a package consumer, I want the package metadata to reflect the new name, so that I can find and use the correct package.

#### Acceptance Criteria

1. THE `name` field in `packages/dddart_rest/pubspec.yaml` SHALL be `dddart_rest`
2. THE `description` field SHALL emphasize "RESTful CRUD API" rather than generic "HTTP"
3. THE version number SHALL remain `0.9.0` (no version bump for rename)
4. THE repository URL SHALL be updated if the package has its own repository

### Requirement 4: Import Statement Updates

**User Story:** As a developer using the package, I want all import statements to use the new package name, so that my code compiles correctly.

#### Acceptance Criteria

1. ALL import statements `import 'package:dddart_http/...` SHALL be changed to `import 'package:dddart_rest/...`
2. THE change SHALL apply to all Dart files in the workspace
3. THE change SHALL apply to example code
4. THE change SHALL apply to test files

### Requirement 5: Internal Reference Updates

**User Story:** As a developer, I want all internal package references to use the new name, so that dependencies resolve correctly.

#### Acceptance Criteria

1. ALL references to `dddart_http` in other packages' pubspec.yaml files SHALL be changed to `dddart_rest`
2. THE workspace configuration in root pubspec.yaml SHALL list `packages/dddart_rest`
3. ALL path dependencies SHALL reference the new directory name

### Requirement 6: Documentation Updates

**User Story:** As a developer reading documentation, I want all references to use the new package name, so that I'm not confused by outdated information.

#### Acceptance Criteria

1. ALL README files SHALL reference `dddart_rest` instead of `dddart_http`
2. ALL code examples in documentation SHALL use `import 'package:dddart_rest/dddart_rest.dart'`
3. THE main package README SHALL explain the rename and purpose clearly
4. ALL spec documents SHALL be updated to reference the new name

### Requirement 7: Logging Configuration Updates

**User Story:** As a developer using logging, I want logger names to reflect the new package name, so that log filtering is intuitive.

#### Acceptance Criteria

1. THE logger name `dddart.http` SHALL be changed to `dddart.rest`
2. ALL documentation referencing logger names SHALL be updated
3. ALL code creating loggers SHALL use the new name
4. THE change SHALL maintain backward compatibility where possible

### Requirement 8: Backward Compatibility Communication

**User Story:** As an existing user of dddart_http, I want clear migration guidance, so that I can update my code smoothly.

#### Acceptance Criteria

1. THE package README SHALL include a "Migration from dddart_http" section
2. THE migration guide SHALL list all required changes (imports, dependencies, logger names)
3. THE CHANGELOG SHALL document the rename with migration instructions
4. THE version number SHALL indicate this is a breaking change when published

### Requirement 9: Build and Test Verification

**User Story:** As a developer, I want all tests to pass after the rename, so that I know the rename didn't break functionality.

#### Acceptance Criteria

1. ALL tests in `packages/dddart_rest/test/` SHALL pass after the rename
2. ALL tests in dependent packages SHALL pass after updating their dependencies
3. THE workspace SHALL resolve dependencies correctly
4. ALL example applications SHALL run successfully

### Requirement 10: Consistency Across Ecosystem

**User Story:** As a developer working with the DDDart ecosystem, I want consistent naming patterns, so that package purposes are clear.

#### Acceptance Criteria

1. THE package naming SHALL follow the pattern: `dddart_<specific_purpose>`
2. THE name `dddart_rest` SHALL clearly indicate REST/CRUD functionality
3. THE name SHALL not conflict with or confuse `dddart_webhooks`
4. THE naming SHALL align with other packages: `dddart_json`, `dddart_serialization`, `dddart_config`
