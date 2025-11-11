# Project Structure

## Monorepo Organization

```
packages/
├── dddart/              # Core DDD framework
├── dddart_serialization/ # Serialization framework
├── dddart_json/         # JSON serialization implementation
└── dddart_http/         # HTTP CRUD API framework
```

## Standard Package Layout

Each package follows Dart conventions:

```
package_name/
├── .dart_tool/          # Build artifacts (ignored)
├── .git/                # Independent git repository
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

- Runnable Dart files demonstrating usage
- May have own `lib/` for domain models
- Include README.md explaining examples
- Own pubspec.yaml with dependencies

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

- `.dart_tool/` - Build artifacts
- `.git/` - Version control (each package has own)
- `build/` - Build output
- `coverage/` - Test coverage reports
