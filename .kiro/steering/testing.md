# Testing and Quality Standards

## Testing Requirements for Specs

All specs MUST include comprehensive testing as part of the implementation plan. Testing is not optional - it's a core requirement for ensuring code quality and maintainability.

## Test Coverage Expectations

- **Unit Tests**: Test individual classes, methods, and functions in isolation
- **Integration Tests**: Test interactions between components and subsystems
- **Edge Cases**: Test boundary conditions, error handling, and exceptional scenarios
- **Regression Tests**: Ensure existing functionality remains intact

## Testing Strategy

### What to Test

- Core business logic and domain rules
- Public APIs and interfaces
- Error handling and validation
- State transitions and side effects
- Integration points between components

### Test Organization

- Mirror the `lib/` structure in `test/` directory
- One test file per implementation file: `class_name_test.dart` for `class_name.dart`
- Use `group()` to organize related tests
- Use descriptive test names that explain the scenario and expected outcome

### Test Quality

- Tests should be independent and not rely on execution order
- Use setup/teardown (`setUp()`, `tearDown()`) for common initialization
- Mock external dependencies to isolate units under test
- Assert both positive cases (expected behavior) and negative cases (error handling)
- Keep tests focused - one logical assertion per test when possible

## Testing in Spec Workflow

### Requirements Phase

- Acceptance criteria should be testable
- Each requirement should map to one or more test scenarios

### Design Phase

- Testing strategy section MUST outline:
  - What will be tested (unit, integration, edge cases)
  - How components will be tested in isolation
  - What mocking or test doubles are needed
  - Any test utilities or helpers required

### Implementation Phase

- Test tasks should be integrated with implementation tasks
- Follow test-driven development when appropriate
- Write tests that validate requirements and design decisions
- Ensure all tests pass before marking tasks complete

## Dart Testing Best Practices

```dart
import 'package:test/test.dart';

void main() {
  group('ClassName', () {
    late ClassName instance;
    
    setUp(() {
      instance = ClassName();
    });
    
    test('should do expected behavior when condition is met', () {
      // Arrange
      final input = 'test';
      
      // Act
      final result = instance.method(input);
      
      // Assert
      expect(result, equals(expectedValue));
    });
    
    test('should throw exception when invalid input provided', () {
      expect(
        () => instance.method(null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

## Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/class_name_test.dart

# Run with coverage
dart test --coverage=coverage

# Run tests in watch mode during development
dart test --watch
```

## Quality Gates

Before marking any implementation task as complete:

1. All tests must pass
2. No compiler warnings or errors
3. Code follows Dart linting rules
4. Test coverage is adequate for the feature
5. Edge cases and error scenarios are tested
6. **`./scripts/test-all.sh` must pass completely** - This is the definitive quality gate

### Local Test Script Compliance

**MANDATORY**: The local test script (`./scripts/test-all.sh`) defines the quality standards for this project. Before completing any task or committing code:

1. Run `./scripts/test-all.sh` from the workspace root
2. Fix ALL issues reported by the script:
   - Analysis errors and warnings (`dart analyze --fatal-infos`)
   - Formatting issues (`dart format --set-exit-if-changed`)
   - Test failures (`dart test`)
3. The script must complete with exit code 0 (success)

**Why this matters:**
- The local script mirrors the CI/CD checks exactly
- If the local script passes, CI/CD will pass
- The pre-push hook runs this script automatically
- This prevents broken code from being pushed

**Common fixes:**
- Run `dart fix --apply` to auto-fix many linting issues
- Run `dart format .` to fix formatting
- Check for unused imports, variables, and other warnings
- Ensure all tests pass locally before pushing

## Test Infrastructure Maintenance

**CRITICAL**: When adding new packages or changing test requirements, you MUST update:

1. **`.github/workflows/test.yml`** - GitHub Actions CI/CD workflow
   - Add new packages to the `matrix.package` list
   - Update test commands if test requirements change

2. **`scripts/test-all.sh`** - Local test script (used by pre-push hook)
   - Add new packages to the `PACKAGES` array
   - Keep test commands in sync with GitHub Actions

3. **Root `pubspec.yaml`** - Workspace configuration
   - Add new packages to the `workspace:` list

**Why this matters:**
- Ensures new packages are tested in CI/CD
- Ensures pre-push hook catches issues before pushing
- Maintains consistency between local and CI environments
- Prevents untested code from being merged

**Verification:**
After adding a new package, verify it's tested by running:
```bash
./scripts/test-all.sh
```

The script should include your new package in its output.
