// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_user.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class SimpleUserJsonSerializer implements JsonSerializer<SimpleUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  SimpleUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    SimpleUser instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('age', effectiveConfig.fieldRename):
          instance.age,
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename(
        'isActive',
        effectiveConfig.fieldRename,
      ): instance.isActive,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  SimpleUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize SimpleUser from null JSON',
        expectedType: 'SimpleUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'SimpleUser',
      );
    }
    try {
      return SimpleUser(
        age:
            json[SerializationUtils.applyFieldRename(
                  'age',
                  effectiveConfig.fieldRename,
                )]
                as int,
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        isActive:
            json[SerializationUtils.applyFieldRename(
                  'isActive',
                  effectiveConfig.fieldRename,
                )]
                as bool,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize SimpleUser: $e',
        expectedType: 'SimpleUser',
      );
    }
  }

  @override
  String serialize(SimpleUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  SimpleUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'SimpleUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    SimpleUser instance, [
    SerializationConfig? config,
  ]) {
    return SimpleUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static SimpleUser decode(dynamic json, [SerializationConfig? config]) {
    return SimpleUserJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// SqliteRepositoryGenerator
// **************************************************************************

/// Generated SQLite repository for [SimpleUser] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class SimpleUserSqliteRepository implements Repository<SimpleUser> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  SimpleUserSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for SimpleUser aggregates.
  final _serializer = SimpleUserJsonSerializer();

  /// The table name for SimpleUser aggregates.
  String get tableName => 'users';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: users
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "users" (
  "name" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "age" INTEGER NOT NULL,
  "isActive" INTEGER NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');
    });
  }

  @override
  Future<SimpleUser> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "users" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'SimpleUser with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(SimpleUser aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, []);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "users" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );
      } catch (e) {
        throw _mapSqliteException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "users" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'SimpleUser with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM "users" WHERE "id" = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
      }
    });
  }

  /// Flattens JSON for table storage, excluding specified keys.
  Map<String, dynamic> _flattenForTable(
    Map<String, dynamic> json,
    List<String> excludeKeys,
  ) {
    final flattened = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (excludeKeys.contains(key)) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Flatten nested object (value object) with prefix
        for (final nestedEntry in value.entries) {
          flattened['${key}_${nestedEntry.key}'] = nestedEntry.value;
        }
      } else if (value is List) {
        // Skip lists - they're handled separately
        continue;
      } else {
        flattened[key] = value;
      }
    }

    return flattened;
  }

  /// Converts a SQL row to JSON, reconstructing embedded value objects.
  Map<String, dynamic> _rowToJson(Map<String, Object?> row) {
    final json = <String, dynamic>{};
    final processedPrefixes = <String>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this is a prefixed column (value object field)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final prefix = parts[0];

          // Skip if already processed
          if (processedPrefixes.contains(prefix)) continue;

          // Collect all columns with this prefix
          final prefixedColumns = row.entries
              .where((e) => e.key.startsWith('${prefix}_'))
              .toList();

          if (prefixedColumns.isNotEmpty) {
            // Reconstruct value object
            final valueObject = <String, dynamic>{};
            var allNull = true;
            for (final col in prefixedColumns) {
              final fieldName = col.key.substring(prefix.length + 1);
              final decoded = _decodeValue(col.value, fieldName);
              valueObject[fieldName] = decoded;
              if (decoded != null) allNull = false;
            }
            // Only add if not all null (nullable value object)
            json[prefix] = allNull ? null : valueObject;
            processedPrefixes.add(prefix);
            continue;
          }
        }
      }

      // Regular field
      json[key] = _decodeValue(value, key);
    }

    return json;
  }

  /// Maps field names to their Dart types for type-aware encoding/decoding.
  static const Map<String, String> _fieldTypes = {
    'name': 'String',
    'email': 'String',
    'age': 'int',
    'isActive': 'bool',
    'id': 'UuidValue',
    'createdAt': 'DateTime',
    'updatedAt': 'DateTime',
  };

  /// Encodes a value for SQL storage.
  Object? _encodeValue(dynamic value) {
    if (value == null) return null;

    // Handle UUID strings
    if (value is String && value.contains('-') && value.length == 36) {
      try {
        return _dialect.encodeUuid(UuidValue.fromString(value));
      } catch (_) {
        return value;
      }
    }

    // Handle DateTime strings
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) {
        return _dialect.encodeDateTime(dateTime);
      }
    }

    // Handle booleans
    if (value is bool) {
      return value ? 1 : 0;
    }

    return value;
  }

  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // Decode UUIDs (BLOB)
    if (value is List<int> &&
        (dartType == 'UuidValue' ||
            fieldName == 'id' ||
            fieldName.endsWith('Id'))) {
      try {
        return _dialect.decodeUuid(value).toString();
      } catch (_) {
        return value;
      }
    }

    // Decode DateTimes (TEXT in ISO8601 format)
    if (dartType == 'DateTime' && value is String) {
      try {
        return _dialect.decodeDateTime(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (INTEGER 0/1)
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific SQLite error patterns to RepositoryExceptionType
    if (errorMessage.contains('UNIQUE constraint')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    if (errorMessage.contains('database is locked') ||
        errorMessage.contains('unable to open database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    return RepositoryException(
      'SQLite error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }
}
