// SQL Repository Exception Mapping Strategy
//
// SQL repository implementations MUST use RepositoryException from the
// dddart package for all repository operations. This ensures consistent
// error handling across all repository implementations.
//
// ## Exception Type Mapping
//
// SQL database errors should be mapped to RepositoryExceptionType as follows:
//
// ### notFound
// - SQL: No rows returned from SELECT by ID
// - SQL: DELETE affected 0 rows
// - Example: `SELECT * FROM users WHERE id = ? LIMIT 1` returns empty
//
// ### duplicate
// - SQL: UNIQUE constraint violation
// - SQL: PRIMARY KEY constraint violation
// - SQLite error code: SQLITE_CONSTRAINT_UNIQUE (2067)
// - PostgreSQL error code: 23505
// - MySQL error code: 1062
//
// ### constraint
// - SQL: FOREIGN KEY constraint violation
// - SQL: CHECK constraint violation
// - SQL: NOT NULL constraint violation
// - SQLite error codes: SQLITE_CONSTRAINT_* (except UNIQUE)
// - PostgreSQL error codes: 23xxx (except 23505)
// - MySQL error codes: 1216, 1217, 1451, 1452
//
// ### connection
// - SQL: Cannot open database file
// - SQL: Connection refused
// - SQL: Connection lost during operation
// - SQLite error codes: SQLITE_CANTOPEN, SQLITE_IOERR
// - PostgreSQL error codes: 08xxx
// - MySQL error codes: 2002, 2003, 2006, 2013
//
// ### timeout
// - SQL: Query execution timeout
// - SQL: Lock wait timeout
// - SQLite error code: SQLITE_BUSY
// - PostgreSQL error code: 57014
// - MySQL error code: 1205
//
// ### unknown
// - Any SQL error not covered by the above categories
// - Unexpected database errors
// - Should include the original error as RepositoryException.cause
//
// ## Implementation Example
//
// ```dart
// try {
//   final result = await connection.query('SELECT * FROM users WHERE id = ?', [id]);
//   if (result.isEmpty) {
//     throw RepositoryException(
//       'User not found with id: $id',
//       type: RepositoryExceptionType.notFound,
//     );
//   }
//   return deserialize(result.first);
// } on SqliteException catch (e) {
//   throw _mapSqliteException(e);
// }
//
// RepositoryException _mapSqliteException(SqliteException e) {
//   switch (e.extendedResultCode) {
//     case 2067: // SQLITE_CONSTRAINT_UNIQUE
//       return RepositoryException(
//         'Duplicate entry: ${e.message}',
//         type: RepositoryExceptionType.duplicate,
//         cause: e,
//       );
//     case 5: // SQLITE_BUSY
//       return RepositoryException(
//         'Database locked: ${e.message}',
//         type: RepositoryExceptionType.timeout,
//         cause: e,
//       );
//     // ... other cases
//     default:
//       return RepositoryException(
//         'Database error: ${e.message}',
//         type: RepositoryExceptionType.unknown,
//         cause: e,
//       );
//   }
// }
// ```
//
// ## Best Practices
//
// 1. **Always include the original exception as cause**: This preserves the
//    full error context for debugging.
//
// 2. **Provide descriptive messages**: Include relevant context like IDs,
//    table names, or operation types.
//
// 3. **Map errors consistently**: Use the same mapping logic across all
//    repository methods.
//
// 4. **Test error mapping**: Write tests to verify each error type is
//    correctly mapped.
//
// 5. **Document database-specific codes**: Maintain a reference of error
//    codes for each supported database.
