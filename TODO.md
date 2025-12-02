# TODO

## Testing Improvements

### Add Property-Based Tests to MongoDB Repository

**Context:** The MySQL and DynamoDB repositories have comprehensive property-based tests (PBT) that validate correctness properties across many randomized inputs. MongoDB currently only has integration tests.

**Current State:**
- ✅ MySQL: Has property tests with `property-test` tag
- ✅ DynamoDB: Has property tests with `property-test` tag  
- ✅ SQLite: Has property tests with `property-test` tag
- ✅ MongoDB: Has property tests with `property-test` tag

**What needs to be done:**

1. ✅ **COMPLETED: Add property test files** similar to MySQL structure:
   - ✅ `connection_property_test.dart` - Connection lifecycle, error handling
   - ✅ `generator_property_test.dart` - Code generation completeness
   - ✅ `repository_property_test.dart` - CRUD operations, round-trip persistence

2. ✅ **COMPLETED: Standardize property test tagging** across all repositories:
   - ✅ Standardized on `property-test` tag across all repositories
   - ✅ Updated DynamoDB from `property` to `property-test`
   - ✅ Added `property-test` tag to SQLite property tests
   - ✅ Configured in `dart_test.yaml` with 2x timeout for all repositories
   - ✅ All property tests run by default (no skip configuration)

3. ✅ **COMPLETED: Benefits achieved:**
   - ✅ Validates correctness properties across many inputs
   - ✅ Catches edge cases that example-based tests miss
   - ✅ Provides formal verification of design properties
   - ✅ Maintains consistency across repository implementations

**Reference:**
- See `packages/dddart_repository_mysql/test/*_property_test.dart` for examples
- See `.kiro/specs/mysql-repository/design.md` for property definitions
- Property tests typically run 10-100+ iterations with randomized data

**Status:** ✅ COMPLETED - All repository packages now have comprehensive property-based tests with standardized tagging.
