# Design Document: Package Rename from dddart_http to dddart_rest

## Overview

This document outlines the design for renaming the `dddart_http` package to `dddart_rest` to better communicate its specific purpose of providing RESTful CRUD APIs for DDD aggregate roots. The rename will improve clarity and distinguish this package from `dddart_webhooks`, which handles incoming webhook requests.

## Rationale

### Why Rename?

1. **Clarity**: "http" is too generic - the package specifically provides REST CRUD operations, not general HTTP handling
2. **Distinction**: Webhooks are also HTTP-based, creating confusion about package boundaries
3. **Accuracy**: The package is focused on RESTful patterns (GET, POST, PUT, DELETE for resources)
4. **Discoverability**: Developers looking for REST/CRUD functionality will find it more easily

### Why "dddart_rest"?

- **REST** clearly indicates RESTful API patterns
- Aligns with the package's actual functionality (CRUD operations on resources)
- Distinguishes from `dddart_webhooks` (incoming webhook handling)
- Follows the `dddart_<purpose>` naming convention
- Short and memorable

### Alternatives Considered

- `dddart_crud_api`: More explicit but verbose
- `dddart_api`: Too generic, doesn't convey REST/CRUD focus
- `dddart_rest_api`: Redundant (REST implies API)

## Architecture

### Package Structure (After Rename)

```
packages/dddart_rest/
├── lib/
│   ├── dddart_rest.dart          # Main export (renamed from dddart_http.dart)
│   └── src/
│       ├── crud_resource.dart     # No changes to implementation
│       ├── error_mapper.dart
│       ├── exceptions.dart
│       ├── http_server.dart       # Logger name updated
│       ├── query_handler.dart
│       └── response_builder.dart
├── test/
│   └── *.dart                     # Import statements updated
├── example/
│   ├── pubspec.yaml               # Package name updated
│   ├── main.dart                  # Import statements updated
│   └── lib/
├── pubspec.yaml                   # Package name updated
└── README.md                      # All references updated
```

### Dependency Graph (After Rename)

```
dddart_rest
├── depends on: dddart, dddart_serialization, shelf, shelf_router, logging
└── depended on by: (none currently, but examples use it)

dddart_webhooks
├── depends on: shelf, logging
└── depended on by: dddart_webhooks_slack

dddart_webhooks_slack
└── depends on: dddart, dddart_webhooks, shelf, crypto
```

No circular dependencies. Clean separation of concerns.

## Components and Changes

### 1. File System Changes

**Directory Rename:**
```bash
packages/dddart_http/ → packages/dddart_rest/
```

**File Renames:**
```bash
lib/dddart_http.dart → lib/dddart_rest.dart
```

**No changes to:**
- All files in `lib/src/` (implementation unchanged)
- Test file names (only imports change)
- Example structure (only pubspec and imports change)

### 2. Package Metadata Changes

**packages/dddart_rest/pubspec.yaml:**
```yaml
name: dddart_rest  # Changed from dddart_http
description: RESTful CRUD API framework for DDDart - Provides REST endpoints for aggregate roots
# ... rest unchanged
```

**packages/dddart_rest/example/pubspec.yaml:**
```yaml
name: dddart_rest_example  # Changed from dddart_http_example
description: Example application demonstrating dddart_rest CRUD API
dependencies:
  dddart_rest:  # Changed from dddart_http
    git:
      url: https://github.com/continuousimagination/dddart_rest.git
```

### 3. Library Declaration Changes

**lib/dddart_rest.dart:**
```dart
/// RESTful CRUD API framework for DDDart
///
/// Provides a declarative, type-safe way to expose aggregate roots through
/// RESTful HTTP endpoints with support for content negotiation, custom query
/// handlers, and extensible error handling.
library dddart_rest;  // Changed from dddart_http

export 'src/crud_resource.dart';
export 'src/error_mapper.dart';
export 'src/exceptions.dart';
export 'src/http_server.dart';
export 'src/query_handler.dart';
export 'src/response_builder.dart';
```

### 4. Import Statement Pattern Changes

**Before:**
```dart
import 'package:dddart_http/dddart_http.dart';
import 'package:dddart_http/src/crud_resource.dart';
```

**After:**
```dart
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_rest/src/crud_resource.dart';
```

### 5. Logger Name Changes

**lib/src/http_server.dart and lib/src/crud_resource.dart:**

**Before:**
```dart
final _log = Logger('dddart.http');
```

**After:**
```dart
final _log = Logger('dddart.rest');
```

### 6. Workspace Configuration Changes

**Root pubspec.yaml:**
```yaml
workspace:
  - packages/dddart
  - packages/dddart_serialization
  - packages/dddart_json
  - packages/dddart_rest  # Changed from dddart_http
  - packages/dddart_config
  - packages/dddart_webhooks
  - packages/dddart_webhooks_slack
```

## Data Models

No data model changes - this is purely a naming/organizational change.

## Error Handling

No error handling changes - all exception types and error responses remain the same.

## Testing Strategy

### Test Categories

1. **Unit Tests**: No changes to test logic, only import statements
2. **Integration Tests**: No changes to test logic, only import statements
3. **Example Applications**: Update imports and verify they run

### Verification Steps

1. Run `dart pub get` in workspace root
2. Run `dart test` in `packages/dddart_rest/`
3. Run example applications
4. Verify no broken imports across workspace
5. Check that all documentation renders correctly

### Test Files to Update

All test files in `packages/dddart_rest/test/`:
- `crud_resource_test.dart`
- `error_mapper_test.dart`
- `http_server_test.dart`
- `integration_test.dart`
- `optional_logging_test.dart`
- `query_handler_test.dart`
- `response_builder_test.dart`

## Migration Guide

### For Package Maintainers

1. Rename directory: `mv packages/dddart_http packages/dddart_rest`
2. Update pubspec.yaml name field
3. Rename main library file
4. Update all import statements
5. Update logger names
6. Update workspace configuration
7. Run tests
8. Update documentation

### For Package Users

**Step 1: Update pubspec.yaml**
```yaml
dependencies:
  dddart_rest: ^0.9.0  # Changed from dddart_http
```

**Step 2: Update imports**
```dart
// Before
import 'package:dddart_http/dddart_http.dart';

// After
import 'package:dddart_rest/dddart_rest.dart';
```

**Step 3: Update logger configuration (if used)**
```dart
// Before
Logger('dddart.http').level = Level.INFO;

// After
Logger('dddart.rest').level = Level.INFO;
```

**Step 4: Run pub get and test**
```bash
dart pub get
dart test
```

## Documentation Updates

### Files Requiring Updates

1. **packages/dddart_rest/README.md**
   - Update title and all references
   - Add migration section
   - Update code examples

2. **.kiro/steering/product.md**
   - Update package list
   - Update descriptions

3. **.kiro/steering/structure.md**
   - Update directory tree
   - Update package references

4. **.kiro/steering/tech.md**
   - Update dependency list
   - Update package references

5. **.kiro/specs/webhook-support/design.md**
   - Update integration examples
   - Update dependency references

6. **.kiro/specs/webhook-support/tasks.md**
   - Update task descriptions
   - Update package references

7. **.kiro/specs/logging-system/***
   - Update logger names
   - Update package references

8. **packages/dddart/README.md**
   - Update logger hierarchy
   - Update examples

## Rollout Plan

### Phase 1: Preparation
1. Create this design document
2. Review with stakeholders
3. Create implementation tasks

### Phase 2: Rename Execution
1. Rename directory
2. Update package metadata
3. Update library declarations
4. Update all imports
5. Update logger names

### Phase 3: Documentation
1. Update all README files
2. Update steering documents
3. Update spec documents
4. Add migration guide

### Phase 4: Verification
1. Run all tests
2. Run example applications
3. Verify documentation
4. Check for any missed references

### Phase 5: Communication
1. Update CHANGELOG
2. Prepare migration guide
3. Update any external documentation
4. Communicate to users (if package is published)

## Risks and Mitigation

### Risk 1: Broken Imports
**Mitigation**: Use grep to find all references before making changes, verify with tests after

### Risk 2: Missed References in Documentation
**Mitigation**: Search entire codebase for "dddart_http" string, update all occurrences

### Risk 3: External Dependencies
**Mitigation**: Currently no external packages depend on this (not published), so risk is minimal

### Risk 4: Git History Confusion
**Mitigation**: Use `git mv` to preserve history, document rename in commit message

## Success Criteria

1. All tests pass in renamed package
2. Example applications run successfully
3. No references to "dddart_http" remain in codebase (except CHANGELOG/migration docs)
4. Documentation is clear and accurate
5. Package purpose is immediately clear from name
6. No confusion with dddart_webhooks
