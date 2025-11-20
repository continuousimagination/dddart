# Project Structure

## Monorepo Organization

This project uses **Dart Workspaces** (SDK 3.5+) to manage multiple packages in a monorepo.

```
.
├── pubspec.yaml         # Workspace root configuration
└── packages/
    ├── dddart/              # Core DDD framework
    ├── dddart_serialization/ # Serialization framework
    ├── dddart_json/         # JSON serialization implementation
    ├── dddart_rest/         # RESTful CRUD API framework
    ├── dddart_config/       # Configuration management
    ├── dddart_repository_mongodb/ # MongoDB repository implementation
    ├── dddart_webhooks/     # Webhook framework
    └── dddart_webhooks_slack/ # Slack webhook integration
```

### Workspace Configuration

The root `pubspec.yaml` defines the workspace:

```yaml
name: _dddart_workspace
publish_to: none

workspace:
  - packages/dddart
  - packages/dddart_serialization
  # ... all packages
```

### Working with Workspaces

**IMPORTANT**: When working with this workspace:

- **Always run `dart pub get` from the workspace root** (not from individual packages)
- This resolves all packages and their dependencies together
- Individual packages reference each other using `resolution: workspace` in their pubspec.yaml
- The `.dart_tool/package_config.json` is managed at the workspace level

**Commands:**

```bash
# Get dependencies (run from root)
dart pub get

# Run tests for a specific package
cd packages/package_name && dart test

# Analyze a specific package
cd packages/package_name && dart analyze

# Format code (run from root for all packages)
dart format .
```

## Standard Package Layout

Each package follows Dart conventions:

```
package_name/
├── lib/
│   ├── package_name.dart  # Main library export file
│   └── src/             # Implementation files (private)
├── test/                # Test files (*_test.dart)
├── example/             # Example usage
│   ├── lib/             # Example domain models
│   └── *.dart           # Runnable examples
├── pubspec.yaml         # Package dependencies
├── README.md            # Package documentation
├── LICENSE              # MIT License
└── CHANGELOG.md         # Version history
```

## Code Organization Patterns

### Library Exports (lib/package_name.dart)

Export all public classes from src/ directory:

```dart
library package_name;

export 'src/class1.dart';
export 'src/class2.dart';
```

### Implementation Files (lib/src/)

- One class per file (typically)
- Private implementation details
- Imported by main library file

### Test Files (test/)

- Mirror lib/ structure
- Named `*_test.dart`
- Use `package:test` framework
- Group tests logically with `group()` and `test()`

### Examples (example/)

- **REQUIRED**: Every package MUST include an `example/` directory
- Runnable Dart files demonstrating usage
- May have own `lib/` for domain models
- Include README.md explaining examples
- Own pubspec.yaml with dependencies
- Examples should cover common use cases and integration patterns

## Generated Files

### dddart_json

- `*.g.dart` - Generated serializer classes
- Pattern: `{filename}.g.dart` for `{filename}.dart`
- Include `part` directive in source: `part 'filename.g.dart';`
- Committed to version control

## Documentation Files

- **README.md**: Package overview, features, quick start, API reference
- **GETTING_STARTED.md**: 5-minute quick start guide (dddart)
- **DOMAIN_EVENTS_GUIDE.md**: Comprehensive patterns guide (dddart)
- **API_REFERENCE.md**: Complete API documentation (dddart)
- **DOCUMENTATION_INDEX.md**: Documentation navigation (dddart)

## Key Directories to Ignore

- `.dart_tool/` - Build artifacts (managed at workspace root)
- `build/` - Build output
- `coverage/` - Test coverage reports

## Adding New Packages

**IMPORTANT**: When adding a new package to the workspace, you MUST update:

1. **Root `pubspec.yaml`** - Add the package to the `workspace:` list
2. **`.github/workflows/test.yml`** - Add the package to the `matrix.package` list
3. **`scripts/test-all.sh`** - Add the package to the `PACKAGES` array

This ensures the new package is:
- Included in workspace dependency resolution
- Tested in CI/CD (GitHub Actions)
- Tested locally (pre-push hook)

**Example:**
```yaml
# pubspec.yaml
workspace:
  - packages/new_package

# .github/workflows/test.yml
matrix:
  package:
    - new_package

# scripts/test-all.sh
PACKAGES=(
  "new_package"
)
```

## CI/CD Considerations

When setting up CI/CD (like GitHub Actions):

1. Run `dart pub get` from the workspace root first
2. Then run package-specific commands (analyze, test, format) from each package directory
3. This ensures proper package resolution and dependency management

Example GitHub Actions workflow:

```yaml
- name: Get dependencies (workspace)
  run: dart pub get

- name: Analyze code
  run: dart analyze --fatal-infos
  working-directory: packages/${{ matrix.package }}
```

**Maintenance**: The GitHub Actions workflow (`.github/workflows/test.yml`) and the local test script (`scripts/test-all.sh`) must be kept in sync. Both should test the same packages with the same checks.
