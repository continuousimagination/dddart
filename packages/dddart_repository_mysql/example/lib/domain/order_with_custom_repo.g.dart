// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_with_custom_repo.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class OrderWithCustomRepoJsonSerializer
    implements JsonSerializer<OrderWithCustomRepo> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  OrderWithCustomRepoJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    OrderWithCustomRepo instance, [
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
      if (instance.billingAddress != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'billingAddress',
          effectiveConfig.fieldRename,
        ): instance.billingAddress != null
            ? AddressJsonSerializer().toJson(
                instance.billingAddress!,
                effectiveConfig,
              )
            : null,
      SerializationUtils.applyFieldRename(
        'customerName',
        effectiveConfig.fieldRename,
      ): instance.customerName,
      SerializationUtils.applyFieldRename(
        'items',
        effectiveConfig.fieldRename,
      ): instance.items
          .map(
            (item) => OrderItemJsonSerializer().toJson(item, effectiveConfig),
          )
          .toList(),
      SerializationUtils.applyFieldRename(
        'shippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.shippingAddress,
        effectiveConfig,
      ),
    };
    return json;
  }

  @override
  OrderWithCustomRepo fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize OrderWithCustomRepo from null JSON',
        expectedType: 'OrderWithCustomRepo',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'OrderWithCustomRepo',
      );
    }
    try {
      return OrderWithCustomRepo(
        billingAddress:
            json[SerializationUtils.applyFieldRename(
                  'billingAddress',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? AddressJsonSerializer().fromJson(
                json[SerializationUtils.applyFieldRename(
                      'billingAddress',
                      effectiveConfig.fieldRename,
                    )]
                    as Map<String, dynamic>,
                effectiveConfig,
              )
            : null,
        customerName:
            json[SerializationUtils.applyFieldRename(
                  'customerName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        items:
            (json[SerializationUtils.applyFieldRename(
                      'items',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => OrderItemJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toList(),
        shippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'shippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
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
        'Failed to deserialize OrderWithCustomRepo',
        expectedType: 'OrderWithCustomRepo',
      );
    }
  }

  @override
  String serialize(OrderWithCustomRepo object, [dynamic config]) {
    try {
      return jsonEncode(toJson(object, config as SerializationConfig?));
    } catch (_) {
      throw SerializationException(
        'Failed to serialize OrderWithCustomRepo',
        expectedType: 'OrderWithCustomRepo',
      );
    }
  }

  @override
  OrderWithCustomRepo deserialize(String data, [dynamic config]) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationException(
          'Expected JSON object',
          expectedType: 'OrderWithCustomRepo',
        );
      }
      return fromJson(json, config as SerializationConfig?);
    } on DeserializationException {
      rethrow;
    } catch (_) {
      throw DeserializationException(
        'Invalid JSON input',
        expectedType: 'OrderWithCustomRepo',
      );
    }
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    OrderWithCustomRepo instance, [
    SerializationConfig? config,
  ]) {
    return OrderWithCustomRepoJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static OrderWithCustomRepo decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return OrderWithCustomRepoJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// MysqlRepositoryGenerator
// **************************************************************************

/// Generated abstract base MySQL repository for [OrderWithCustomRepo] aggregate.
///
/// This abstract class implements the base Repository<OrderWithCustomRepo> methods
/// and declares custom methods as abstract. Extend this class and
/// implement the abstract methods.
abstract class OrderWithCustomRepoMysqlRepositoryBase
    implements OrderRepository {
  /// Creates a repository instance.
  ///
  /// [connection] - An open MySQL database connection.
  OrderWithCustomRepoMysqlRepositoryBase(this._connection);

  /// The MySQL database connection (protected).
  final MysqlConnection _connection;

  /// The SQL dialect for MySQL (protected).
  final _dialect = MysqlDialect();

  /// The JSON serializer (protected).
  final _serializer = OrderWithCustomRepoJsonSerializer();

  /// The table name for OrderWithCustomRepo aggregates.
  String get tableName => 'orders_custom';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: orders_custom
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS orders_custom (
  customerName VARCHAR(255) NOT NULL,
  shippingAddress_street VARCHAR(255) NOT NULL,
  shippingAddress_city VARCHAR(255) NOT NULL,
  shippingAddress_state VARCHAR(255) NOT NULL,
  shippingAddress_postalCode VARCHAR(255) NOT NULL,
  shippingAddress_country VARCHAR(255) NOT NULL,
  billingAddress_street VARCHAR(255),
  billingAddress_city VARCHAR(255),
  billingAddress_state VARCHAR(255),
  billingAddress_postalCode VARCHAR(255),
  billingAddress_country VARCHAR(255),
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');

      // Create table: order_item
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS order_item (
  productName VARCHAR(255) NOT NULL,
  quantity BIGINT NOT NULL,
  unitPrice_amount DOUBLE NOT NULL,
  unitPrice_currency VARCHAR(255) NOT NULL,
  id BINARY(16) PRIMARY KEY NOT NULL,
  createdAt DATETIME NOT NULL,
  updatedAt DATETIME NOT NULL,
  orderscustom_id BINARY(16) NOT NULL,
  _list_position INTEGER NOT NULL,
  FOREIGN KEY (orderscustom_id) REFERENCES `orders_custom`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''');
    });
  }

  @override
  Future<OrderWithCustomRepo> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT `customerName`, `shippingAddress_street`, `shippingAddress_city`, `shippingAddress_state`, `shippingAddress_postalCode`, `shippingAddress_country`, `billingAddress_street`, `billingAddress_city`, `billingAddress_state`, `billingAddress_postalCode`, `billingAddress_country`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt` FROM orders_custom WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'OrderWithCustomRepo with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load nested entities
        json['items'] = await _loadOrderItem(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(OrderWithCustomRepo aggregate) async {
    if (aggregate is VersionedAggregateRoot) {
      throw const RepositoryCapabilityException();
    }
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, ['items']);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
        await _connection.execute(
          'INSERT INTO orders_custom (${columns.join(', ')}) VALUES ($placeholders) '
          'ON DUPLICATE KEY UPDATE $updateClauses',
          values,
        );

        // Save nested entities to their tables
        await _saveOrderItem(aggregate, json);
      } catch (e) {
        throw _mapMysqlException(e, 'save');
      }
    });
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT BIN_TO_UUID(id) as id FROM orders_custom WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'OrderWithCustomRepo with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM orders_custom WHERE id = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }

  /// Saves order_item entities.
  Future<void> _saveOrderItem(
    dynamic aggregate,
    Map<String, dynamic> json,
  ) async {
    // Delete existing entities for this aggregate
    await _connection.execute(
      'DELETE FROM order_item WHERE orderscustom_id = ?',
      [_dialect.encodeUuid(aggregate.id)],
    );

    // Get entities from JSON
    final entitiesJson = json['items'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity with position to preserve List order
    for (var i = 0; i < entitiesJson.length; i++) {
      final entityJson = entitiesJson[i];
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['orderscustom_id'] = aggregate.id.toString();

      // Add position to preserve List order
      entityJson['_list_position'] = i;

      // Generate synthetic ID for entity if not present
      if (!entityJson.containsKey('id')) {
        entityJson['id'] = UuidValue.generate().toString();
      }

      // Flatten and save
      final flattened = _flattenForTable(entityJson, []);
      final columns = flattened.keys.toList();
      final values = columns.map((k) => _encodeValue(flattened[k])).toList();

      final placeholders = List.filled(columns.length, '?').join(', ');
      final updateClauses = columns.map((c) => '$c = VALUES($c)').join(', ');
      await _connection.execute(
        'INSERT INTO order_item (${columns.join(', ')}) VALUES ($placeholders) '
        'ON DUPLICATE KEY UPDATE $updateClauses',
        values,
      );
    }
  }

  /// Loads order_item entities for an aggregate.
  Future<List<Map<String, dynamic>>> _loadOrderItem(
    UuidValue aggregateId,
  ) async {
    final rows = await _connection.query(
      'SELECT `productName`, `quantity`, `unitPrice_amount`, `unitPrice_currency`, BIN_TO_UUID(`id`) as `id`, `createdAt`, `updatedAt`, BIN_TO_UUID(`orderscustom_id`) as `orderscustom_id`, `_list_position` FROM order_item WHERE orderscustom_id = ? ORDER BY _list_position',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Convert rows to JSON and remove the parent FK and position columns
    return rows.map((row) {
      final json = _rowToJson(row);
      json.remove('orderscustom_id');
      json.remove('_list_position');
      return json;
    }).toList();
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
    'customerName': 'String',
    'shippingAddress_street': 'String',
    'shippingAddress_city': 'String',
    'shippingAddress_state': 'String',
    'shippingAddress_postalCode': 'String',
    'shippingAddress_country': 'String',
    'billingAddress_street': 'String',
    'billingAddress_city': 'String',
    'billingAddress_state': 'String',
    'billingAddress_postalCode': 'String',
    'billingAddress_country': 'String',
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

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields

    // Decode DateTimes (DATETIME format)
    if (dartType == 'DateTime') {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        if (value is String) {
          return _dialect.decodeDateTime(value).toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    if (dartType == 'bool' && value is int) {
      return value != 0;
    }

    return value;
  }

  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(Object error, String operation) {
    final errorMessage = error.toString();

    // Map specific MySQL error patterns to RepositoryExceptionType
    // Error 1062: Duplicate entry
    if (errorMessage.contains('1062') ||
        errorMessage.contains('Duplicate entry')) {
      return RepositoryException(
        'Duplicate key error during $operation: $errorMessage',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }

    // Error 2003: Connection refused
    // Error 1045: Access denied
    // Error 1049: Unknown database
    if (errorMessage.contains('2003') ||
        errorMessage.contains('1045') ||
        errorMessage.contains('1049') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Access denied') ||
        errorMessage.contains('Unknown database')) {
      return RepositoryException(
        'Connection error during $operation: $errorMessage',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }

    // Error 1205: Lock wait timeout
    // Error 3024: Query timeout
    if (errorMessage.contains('1205') ||
        errorMessage.contains('3024') ||
        errorMessage.contains('timeout')) {
      return RepositoryException(
        'Timeout during $operation: $errorMessage',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }

    return RepositoryException(
      'MySQL error during $operation: $errorMessage',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }

  // Custom methods (must be implemented by subclass)

  @override
  Future<List<OrderWithCustomRepo>> findByCustomerName(String customerName);

  @override
  Future<List<OrderWithCustomRepo>> findByMinimumAmount(double minAmount);
}
