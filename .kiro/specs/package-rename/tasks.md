# Implementation Plan: Package Rename from dddart_http to dddart_rest

## Task List

- [x] 1. Rename package directory and core files
  - Rename `packages/dddart_http/` directory to `packages/dddart_rest/`
  - Rename `packages/dddart_rest/lib/dddart_http.dart` to `packages/dddart_rest/lib/dddart_rest.dart`
  - Update library declaration in `lib/dddart_rest.dart` from `library dddart_http;` to `library dddart_rest;`
  - _Requirements: 2.1, 2.2_

- [x] 2. Update package metadata files
  - Update `name` field in `packages/dddart_rest/pubspec.yaml` to `dddart_rest`
  - Update `description` field to emphasize "RESTful CRUD API" instead of generic "HTTP"
  - Update `name` field in `packages/dddart_rest/example/pubspec.yaml` to `dddart_rest_example`
  - Update `description` field in example pubspec.yaml
  - _Requirements: 3.1, 3.2_

- [x] 3. Update workspace configuration
  - Update root `pubspec.yaml` workspace list to reference `packages/dddart_rest`
  - Run `dart pub get` to verify workspace resolution
  - _Requirements: 5.2_

- [x] 4. Update import statements in dddart_rest package
  - Update all imports in `packages/dddart_rest/lib/src/*.dart` files from `package:dddart_http/` to `package:dddart_rest/`
  - Update all imports in `packages/dddart_rest/test/*.dart` files
  - Update all imports in `packages/dddart_rest/example/**/*.dart` files
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 5. Update example package dependencies
  - Update `dddart_http` dependency to `dddart_rest` in `packages/dddart_rest/example/pubspec.yaml`
  - Update git URL if applicable
  - Run `dart pub get` in example directory
  - _Requirements: 5.1, 5.3_

- [x] 6. Update logger names
  - Change logger name from `Logger('dddart.http')` to `Logger('dddart.rest')` in `lib/src/http_server.dart`
  - Change logger name from `Logger('dddart.http')` to `Logger('dddart.rest')` in `lib/src/crud_resource.dart`
  - _Requirements: 7.1, 7.2_

- [x] 7. Update main package README
  - Update title from "dddart_http" to "dddart_rest"
  - Update all code examples to use `import 'package:dddart_rest/dddart_rest.dart'`
  - Update dependency examples in pubspec.yaml snippets
  - Add "Migration from dddart_http" section with clear instructions
  - Update description to emphasize RESTful CRUD API focus
  - _Requirements: 6.1, 6.2, 8.1, 8.2_

- [x] 8. Update example README
  - Update title and all references from "dddart_http" to "dddart_rest"
  - Update code examples and import statements
  - Update package references in text
  - _Requirements: 6.1, 6.2_

- [x] 9. Update steering documents
  - Update `.kiro/steering/product.md` package list and descriptions
  - Update `.kiro/steering/structure.md` directory tree and references
  - Update `.kiro/steering/tech.md` dependency list and package references
  - _Requirements: 6.3, 10.4_

- [x] 10. Update webhook spec documents
  - Update `.kiro/specs/webhook-support/design.md` integration examples and dependency references
  - Update `.kiro/specs/webhook-support/tasks.md` task descriptions and package references
  - _Requirements: 6.4_

- [x] 11. Update logging spec documents
  - Update `.kiro/specs/logging-system/requirements.md` logger name references
  - Update `.kiro/specs/logging-system/design.md` logger names and package references
  - Update `.kiro/specs/logging-system/tasks.md` package references
  - _Requirements: 6.4, 7.2_

- [x] 12. Update dddart core package documentation
  - Update `packages/dddart/README.md` logger hierarchy examples
  - Update `packages/dddart/lib/dddart.dart` doc comments about logger names
  - _Requirements: 6.3, 7.3_

- [x] 13. Run tests and verify functionality
  - Run `dart pub get` in workspace root
  - Run `dart test` in `packages/dddart_rest/` directory
  - Verify all tests pass
  - Run example application with `dart run packages/dddart_rest/example/main.dart`
  - Verify example runs without errors
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 14. Search for any remaining references
  - Search entire workspace for string "dddart_http" (excluding git history and this spec)
  - Update any missed references found
  - Verify no broken references remain
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 15. Create CHANGELOG entry
  - Add entry documenting the rename from dddart_http to dddart_rest
  - Include migration instructions
  - Mark as breaking change
  - _Requirements: 8.3_

- [x] 16. Final verification
  - Run `dart analyze` in packages/dddart_rest/ to check for issues
  - Verify workspace dependency resolution with `dart pub get`
  - Run all tests across workspace to ensure no breakage
  - Review all documentation for accuracy
  - _Requirements: 9.1, 9.2, 9.3, 9.4_
