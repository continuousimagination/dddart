# Technology Stack

## Language & SDK

- **Dart SDK**: >=3.0.0 <4.0.0
- **Platform Support**: Server (Dart VM), Web, Mobile (Flutter), Desktop (Flutter)

## Core Dependencies

- **uuid**: ^4.0.0 - UUID generation for entity IDs
- **shelf**: ^1.4.0 - HTTP server framework (dddart_rest)
- **shelf_router**: ^1.1.0 - HTTP routing (dddart_rest)
- **build**: ^2.4.0 - Build system for code generation (dddart_json)
- **source_gen**: ^1.4.0 - Code generation utilities (dddart_json)
- **analyzer**: ^6.0.0 - Dart code analysis (dddart_json)

## Development Tools

- **test**: ^1.24.0 - Testing framework
- **build_runner**: ^2.4.0 - Code generation runner
- **very_good_analysis**: ^6.0.0 - Comprehensive static analysis and linting

## Build System

### Code Generation (dddart_json)

Generate JSON serializers for annotated classes:

```bash
# Generate code
dart run build_runner build

# Generate with conflict resolution
dart run build_runner build --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

### Testing

Run tests for a specific package:

```bash
# Run all tests
dart test

# Run specific test file
dart test test/aggregate_root_test.dart

# Run with coverage
dart test --coverage=coverage

# Exclude tests that require MongoDB
dart test --exclude-tags=requires-mongo
```

### Pre-Push Hook

A pre-push git hook automatically runs all checks before pushing to catch issues early.

**Setup (one-time):**
```bash
./scripts/setup-hooks.sh
```

**What it checks:**
- Workspace dependency resolution
- Code generation (where needed)
- Static analysis (`dart analyze --fatal-infos`)
- Format checking (`dart format --set-exit-if-changed`)
- Tests (excluding `requires-mongo` tagged tests)

**Usage:**
```bash
# The hook runs automatically on git push
git push

# Skip the hook if needed (not recommended)
git push --no-verify

# Run checks manually without pushing
./scripts/test-all.sh
```

The hook calls the versioned `scripts/test-all.sh` script, which mirrors the GitHub Actions workflow.

### Package Management

```bash
# Get dependencies
dart pub get

# Update dependencies
dart pub upgrade

# Publish package (dry run)
dart pub publish --dry-run
```

## Project Structure

Monorepo with multiple packages under `packages/` directory. Each package has:
- Independent git repository (`.git` folder)
- Own `pubspec.yaml` with dependencies
- Standard Dart package structure (lib/, test/, example/)
