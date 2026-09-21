// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complex_order.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class MoneyJsonSerializer implements JsonSerializer<Money> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  MoneyJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Money instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'amount',
        effectiveConfig.fieldRename,
      ): instance.amount,
      SerializationUtils.applyFieldRename(
        'currency',
        effectiveConfig.fieldRename,
      ): instance.currency,
    };
    return json;
  }

  @override
  Money fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Money from null JSON',
        expectedType: 'Money',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Money',
      );
    }
    try {
      return Money(
        amount:
            (json[SerializationUtils.applyFieldRename(
                  'amount',
                  effectiveConfig.fieldRename,
                )]
                is int
            ? (json[SerializationUtils.applyFieldRename(
                        'amount',
                        effectiveConfig.fieldRename,
                      )]
                      as int)
                  .toDouble()
            : json[SerializationUtils.applyFieldRename(
                    'amount',
                    effectiveConfig.fieldRename,
                  )]
                  as double),
        currency:
            json[SerializationUtils.applyFieldRename(
                  'currency',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Money: $e',
        expectedType: 'Money',
      );
    }
  }

  @override
  String serialize(Money object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Money deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Money',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Money instance, [
    SerializationConfig? config,
  ]) {
    return MoneyJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Money decode(dynamic json, [SerializationConfig? config]) {
    return MoneyJsonSerializer().fromJson(json, config);
  }
}

class AddressJsonSerializer implements JsonSerializer<Address> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  AddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Address instance, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('city', effectiveConfig.fieldRename):
          instance.city,
      SerializationUtils.applyFieldRename(
        'country',
        effectiveConfig.fieldRename,
      ): instance.country,
      SerializationUtils.applyFieldRename(
        'street',
        effectiveConfig.fieldRename,
      ): instance.street,
    };
    return json;
  }

  @override
  Address fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Address from null JSON',
        expectedType: 'Address',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Address',
      );
    }
    try {
      return Address(
        city:
            json[SerializationUtils.applyFieldRename(
                  'city',
                  effectiveConfig.fieldRename,
                )]
                as String,
        country:
            json[SerializationUtils.applyFieldRename(
                  'country',
                  effectiveConfig.fieldRename,
                )]
                as String,
        street:
            json[SerializationUtils.applyFieldRename(
                  'street',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize Address: $e',
        expectedType: 'Address',
      );
    }
  }

  @override
  String serialize(Address object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Address deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Address',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Address instance, [
    SerializationConfig? config,
  ]) {
    return AddressJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Address decode(dynamic json, [SerializationConfig? config]) {
    return AddressJsonSerializer().fromJson(json, config);
  }
}

class OrderJsonSerializer implements JsonSerializer<Order> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  OrderJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(Order instance, [SerializationConfig? config]) {
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
      SerializationUtils.applyFieldRename(
        'billingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.billingAddress,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'customerId',
        effectiveConfig.fieldRename,
      ): instance.customerId
          .toString(),
      SerializationUtils.applyFieldRename(
        'customerName',
        effectiveConfig.fieldRename,
      ): instance.customerName,
      SerializationUtils.applyFieldRename('items', effectiveConfig.fieldRename):
          instance.items,
      SerializationUtils.applyFieldRename(
        'shippingAddress',
        effectiveConfig.fieldRename,
      ): AddressJsonSerializer().toJson(
        instance.shippingAddress,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'status',
        effectiveConfig.fieldRename,
      ): instance.status,
      SerializationUtils.applyFieldRename(
        'totalAmount',
        effectiveConfig.fieldRename,
      ): MoneyJsonSerializer().toJson(
        instance.totalAmount,
        effectiveConfig,
      ),
    };
    return json;
  }

  @override
  Order fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize Order from null JSON',
        expectedType: 'Order',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'Order',
      );
    }
    try {
      return Order(
        billingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'billingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        customerId: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'customerId',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        customerName:
            json[SerializationUtils.applyFieldRename(
                  'customerName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        items:
            json[SerializationUtils.applyFieldRename(
                  'items',
                  effectiveConfig.fieldRename,
                )]
                as List<OrderItem>,
        shippingAddress: AddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'shippingAddress',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        status:
            json[SerializationUtils.applyFieldRename(
                  'status',
                  effectiveConfig.fieldRename,
                )]
                as String,
        totalAmount: MoneyJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'totalAmount',
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
        'Failed to deserialize Order: $e',
        expectedType: 'Order',
      );
    }
  }

  @override
  String serialize(Order object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  Order deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'Order',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    Order instance, [
    SerializationConfig? config,
  ]) {
    return OrderJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static Order decode(dynamic json, [SerializationConfig? config]) {
    return OrderJsonSerializer().fromJson(json, config);
  }
}

// **************************************************************************
// SqliteRepositoryGenerator
// **************************************************************************

/// Generated SQLite repository for [Order] aggregate.
///
/// This class provides CRUD operations with full normalization,
/// multi-table persistence, and value object embedding.
class OrderSqliteRepository implements Repository<Order> {
  /// Creates a repository instance.
  ///
  /// [connection] - An open SQLite database connection.
  OrderSqliteRepository(this._connection);

  /// The SQLite database connection.
  final SqliteConnection _connection;

  /// The SQL dialect for SQLite.
  final _dialect = SqliteDialect();

  /// The JSON serializer for Order aggregates.
  final _serializer = OrderJsonSerializer();

  /// The table name for Order aggregates.
  String get tableName => 'orders';

  /// Creates all tables for this aggregate.
  ///
  /// This method should be called once during application
  /// initialization to ensure all required tables exist.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call
  /// multiple times.
  Future<void> createTables() async {
    await _connection.transaction(() async {
      // Create table: order_item
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "order_item" (
  "id" BLOB PRIMARY KEY NOT NULL,
  "productId" BLOB NOT NULL,
  "productName" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "unitPrice_amount" REAL NOT NULL,
  "unitPrice_currency" TEXT NOT NULL,
  "orders_id" BLOB NOT NULL,
  FOREIGN KEY ("orders_id") REFERENCES "orders"("id") ON DELETE CASCADE
)
        ''');

      // Create table: orders
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "orders" (
  "customerId" BLOB NOT NULL,
  "customerName" TEXT NOT NULL,
  "totalAmount_amount" REAL NOT NULL,
  "totalAmount_currency" TEXT NOT NULL,
  "shippingAddress_street" TEXT NOT NULL,
  "shippingAddress_city" TEXT NOT NULL,
  "shippingAddress_country" TEXT NOT NULL,
  "billingAddress_street" TEXT NOT NULL,
  "billingAddress_city" TEXT NOT NULL,
  "billingAddress_country" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "id" BLOB PRIMARY KEY NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL
)
        ''');

      // Create junction table for collection: items
      await _connection.execute('''
CREATE TABLE IF NOT EXISTS "orders_items" (
  "orders_id" BLOB NOT NULL,
  "position" INTEGER NOT NULL,
  "value" TEXT NOT NULL,
  FOREIGN KEY ("orders_id") REFERENCES "orders"("id") ON DELETE CASCADE,
  UNIQUE (orders_id, position)
)
        ''');
    });
  }

  @override
  Future<Order> getById(UuidValue id) async {
    return await _connection.transaction(() async {
      try {
        // Query the aggregate root table
        final rows = await _connection.query(
          'SELECT * FROM "orders" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Order with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        final row = rows.first;
        final json = _rowToJson(row);

        // Load nested entities
        json['items'] = await _loadOrderItem(id);

        // Load collections
        json['items'] = await _loadItems(id);

        return _serializer.fromJson(json);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'getById');
      }
    });
  }

  @override
  Future<void> save(Order aggregate) async {
    await _connection.transaction(() async {
      try {
        // Serialize aggregate to JSON
        final json = _serializer.toJson(aggregate);

        // Save aggregate root first (required for foreign key constraints)
        final rootData = _flattenForTable(json, ['items', 'items']);
        final columns = rootData.keys.toList();
        final values = columns.map((k) => _encodeValue(rootData[k])).toList();

        final placeholders = List.filled(columns.length, '?').join(', ');
        await _connection.execute(
          'INSERT OR REPLACE INTO "orders" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
          values,
        );

        // Save nested entities to their tables
        await _saveOrderItem(aggregate, json);

        // Save collections to their junction tables
        await _saveItems(aggregate.id, json['items']);
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
          'SELECT "id" FROM "orders" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            'Order with ID $id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute('DELETE FROM "orders" WHERE "id" = ?', [
          _dialect.encodeUuid(id),
        ]);
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
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
      'DELETE FROM "order_item" WHERE "orders_id" = ?',
      [_dialect.encodeUuid(aggregate.id)],
    );

    // Get entities from JSON
    final entitiesJson = json['items'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity
    for (final entityJson in entitiesJson) {
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['orders_id'] = aggregate.id.toString();

      // Generate synthetic ID for entity if not present
      if (!entityJson.containsKey('id')) {
        entityJson['id'] = UuidValue.generate().toString();
      }

      // Flatten and save
      final flattened = _flattenForTable(entityJson, []);
      final columns = flattened.keys.toList();
      final values = columns.map((k) => _encodeValue(flattened[k])).toList();

      final placeholders = List.filled(columns.length, '?').join(', ');
      await _connection.execute(
        'INSERT INTO "order_item" (${columns.map((c) => '"$c"').join(', ')}) VALUES ($placeholders)',
        values,
      );
    }
  }

  /// Loads order_item entities for an aggregate.
  Future<List<Map<String, dynamic>>> _loadOrderItem(
    UuidValue aggregateId,
  ) async {
    final rows = await _connection.query(
      'SELECT * FROM "order_item" WHERE "orders_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Convert rows to JSON and remove the parent FK column
    return rows.map((row) {
      final json = _rowToJson(row);
      json.remove('orders_id');
      return json;
    }).toList();
  }

  /// Saves the items collection.
  Future<void> _saveItems(
    UuidValue aggregateId,
    dynamic collectionValue,
  ) async {
    // Delete existing items
    await _connection.execute(
      'DELETE FROM "orders_items" WHERE "orders_id" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Handle null or empty collections
    if (collectionValue == null) return;

    final items = collectionValue as List;
    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final values = <Object?>[
        _dialect.encodeUuid(aggregateId),
        i, // position
        _encodeValue(item),
      ];

      await _connection.execute(
        'INSERT INTO "orders_items" ("orders_id", "position", "value") VALUES (?, ?, ?)',
        values,
      );
    }
  }

  /// Loads the items collection.
  Future<dynamic> _loadItems(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "orders_items" WHERE "orders_id" = ? ORDER BY position',
      [_dialect.encodeUuid(aggregateId)],
    );

    if (rows.isEmpty) {
      return <dynamic>[];
    }

    return rows.map((row) {
      return _decodeValue(row['value'], 'value');
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
    'customerId': 'UuidValue',
    'customerName': 'String',
    'totalAmount_amount': 'double',
    'totalAmount_currency': 'String',
    'shippingAddress_street': 'String',
    'shippingAddress_city': 'String',
    'shippingAddress_country': 'String',
    'billingAddress_street': 'String',
    'billingAddress_city': 'String',
    'billingAddress_country': 'String',
    'status': 'String',
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
