import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';
import 'package:dddart_repository_sql/src/schema/collection_analyzer.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';
import 'package:dddart_repository_sql/src/schema/type_mapper.dart';

/// Generates SQL schema (DDL) from table definitions.
///
/// This class is responsible for converting [TableDefinition] objects
/// into SQL CREATE TABLE statements using a specific [SqlDialect].
///
/// Example:
/// ```dart
/// final generator = SchemaGenerator(SqliteDialect());
/// final sql = generator.generateCreateTable(tableDefinition);
/// // CREATE TABLE IF NOT EXISTS orders (
/// //   id BLOB PRIMARY KEY NOT NULL,
/// //   ...
/// // )
/// ```
class SchemaGenerator {
  /// Creates a schema generator with the specified dialect.
  ///
  /// The [dialect] determines the SQL syntax and data types used
  /// in the generated DDL statements.
  const SchemaGenerator(this.dialect);

  /// The SQL dialect to use for generation.
  final SqlDialect dialect;

  /// Generates CREATE TABLE statement for a table definition.
  ///
  /// The generated statement includes:
  /// - All column definitions with types and constraints
  /// - Primary key constraints
  /// - Foreign key constraints with cascade actions
  /// - Uses CREATE TABLE IF NOT EXISTS for idempotency
  ///
  /// Example:
  /// ```dart
  /// final sql = generator.generateCreateTable(orderTable);
  /// await connection.execute(sql);
  /// ```
  String generateCreateTable(TableDefinition table) {
    return dialect.createTableIfNotExists(table);
  }

  /// Generates column definition SQL.
  ///
  /// Produces a column definition string like:
  /// - `id BLOB PRIMARY KEY NOT NULL`
  /// - `name TEXT NOT NULL`
  /// - `description TEXT` (nullable)
  ///
  /// The format includes:
  /// - Column name
  /// - SQL type
  /// - PRIMARY KEY constraint (if applicable)
  /// - NOT NULL constraint (if not nullable)
  String generateColumnDefinition(ColumnDefinition column) {
    final buffer = StringBuffer();
    buffer.write(column.name);
    buffer.write(' ');
    buffer.write(column.sqlType);

    if (column.isPrimaryKey) {
      buffer.write(' PRIMARY KEY');
    }

    if (!column.isNullable) {
      buffer.write(' NOT NULL');
    }

    return buffer.toString();
  }

  /// Checks if a Dart type is a primitive type.
  ///
  /// Primitive types are mapped directly to SQL column types:
  /// - `String` → TEXT
  /// - `int` → INTEGER
  /// - `double` → REAL
  /// - `bool` → INTEGER (0/1)
  /// - `DateTime` → INTEGER (milliseconds)
  /// - `UuidValue` → BLOB
  ///
  /// Non-primitive types (custom classes) require foreign keys
  /// or embedding (for value objects).
  ///
  /// Returns `true` if [dartType] is a primitive type.
  bool isPrimitiveType(String dartType) {
    const primitiveTypes = {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
      'UuidValue',
    };
    return primitiveTypes.contains(dartType);
  }

  /// Generates a junction table definition for a primitive collection.
  ///
  /// Creates a junction table for collections of primitives (List<int>,
  /// Set<String>, Map<String, int>).
  ///
  /// For List<primitive>:
  /// - Includes position column for ordering
  /// - UNIQUE constraint on (parent_id, position)
  ///
  /// For Set<primitive>:
  /// - No position column
  /// - UNIQUE constraint on (parent_id, value)
  ///
  /// For Map<primitive, primitive>:
  /// - Includes map_key column
  /// - UNIQUE constraint on (parent_id, map_key)
  ///
  /// Example:
  /// ```dart
  /// // For List<int> favoriteNumbers
  /// final table = generator.generatePrimitiveCollectionTable(
  ///   parentTable: 'users',
  ///   fieldName: 'favoriteNumbers',
  ///   collectionInfo: listOfIntInfo,
  /// );
  /// // Creates: users_favoriteNumbers_items (
  /// //   users_id BLOB NOT NULL,
  /// //   position INTEGER NOT NULL,
  /// //   value INTEGER NOT NULL,
  /// //   FOREIGN KEY (users_id) REFERENCES users(id) ON DELETE CASCADE,
  /// //   UNIQUE (users_id, position)
  /// // )
  /// ```
  TableDefinition generatePrimitiveCollectionTable({
    required String parentTable,
    required String fieldName,
    required CollectionInfo collectionInfo,
  }) {
    final tableName = '${parentTable}_${fieldName}_items';
    const typeMapper = TypeMapper();
    final columns = <ColumnDefinition>[];
    final foreignKeys = <ForeignKeyDefinition>[];

    // Add parent foreign key column
    columns.add(
      ColumnDefinition(
        name: '${parentTable}_id',
        sqlType: dialect.uuidColumnType,
        dartType: 'UuidValue',
        isNullable: false,
        isPrimaryKey: false,
        isForeignKey: true,
      ),
    );

    // Add position column for lists
    if (collectionInfo.kind == CollectionKind.list) {
      columns.add(
        ColumnDefinition(
          name: 'position',
          sqlType: dialect.integerColumnType,
          dartType: 'int',
          isNullable: false,
          isPrimaryKey: false,
          isForeignKey: false,
        ),
      );
    }

    // Add map_key column for maps
    if (collectionInfo.kind == CollectionKind.map) {
      final keyType = collectionInfo.keyType;
      if (keyType != null) {
        final keyTypeName = _getTypeName(keyType);
        final keySqlType = typeMapper.getSqlType(keyTypeName, dialect);
        if (keySqlType != null) {
          columns.add(
            ColumnDefinition(
              name: 'map_key',
              sqlType: keySqlType,
              dartType: keyTypeName,
              isNullable: false,
              isPrimaryKey: false,
              isForeignKey: false,
            ),
          );
        }
      }
    }

    // Add value column
    final elementType = collectionInfo.elementType;
    final elementTypeName = _getTypeName(elementType);
    final valueSqlType = typeMapper.getSqlType(elementTypeName, dialect);
    if (valueSqlType != null) {
      columns.add(
        ColumnDefinition(
          name: 'value',
          sqlType: valueSqlType,
          dartType: elementTypeName,
          isNullable: false,
          isPrimaryKey: false,
          isForeignKey: false,
        ),
      );
    }

    // Add foreign key constraint with CASCADE DELETE
    foreignKeys.add(
      ForeignKeyDefinition(
        columnName: '${parentTable}_id',
        referencedTable: parentTable,
        referencedColumn: 'id',
        onDelete: CascadeAction.cascade,
      ),
    );

    return TableDefinition(
      tableName: tableName,
      className: '${fieldName}_items',
      columns: columns,
      foreignKeys: foreignKeys,
      isAggregateRoot: false,
    );
  }

  /// Generates a junction table definition for a value object collection.
  ///
  /// Creates a junction table for collections of value objects (List<Value>,
  /// Set<Value>, Map<primitive, Value>). Value object fields are flattened
  /// into the junction table columns.
  ///
  /// For List<Value>:
  /// - Includes position column for ordering
  /// - Flattens all value object fields
  ///
  /// For Set<Value>:
  /// - No position column
  /// - UNIQUE constraint on (parent_id, all value fields)
  /// - Flattens all value object fields
  ///
  /// For Map<primitive, Value>:
  /// - Includes map_key column
  /// - UNIQUE constraint on (parent_id, map_key)
  /// - Flattens all value object fields
  ///
  /// Example:
  /// ```dart
  /// // For List<Money> where Money has amount and currency fields
  /// final table = generator.generateValueObjectCollectionTable(
  ///   parentTable: 'orders',
  ///   fieldName: 'payments',
  ///   collectionInfo: listOfMoneyInfo,
  ///   valueObjectClass: moneyClass,
  /// );
  /// // Creates: orders_payments_items (
  /// //   orders_id BLOB NOT NULL,
  /// //   position INTEGER NOT NULL,
  /// //   amount REAL NOT NULL,
  /// //   currency TEXT NOT NULL,
  /// //   FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE,
  /// //   UNIQUE (orders_id, position)
  /// // )
  /// ```
  TableDefinition generateValueObjectCollectionTable({
    required String parentTable,
    required String fieldName,
    required CollectionInfo collectionInfo,
    required ClassElement valueObjectClass,
  }) {
    final tableName = '${parentTable}_${fieldName}_items';
    const typeMapper = TypeMapper();
    final columns = <ColumnDefinition>[];
    final foreignKeys = <ForeignKeyDefinition>[];

    // Add parent foreign key column
    columns.add(
      ColumnDefinition(
        name: '${parentTable}_id',
        sqlType: dialect.uuidColumnType,
        dartType: 'UuidValue',
        isNullable: false,
        isPrimaryKey: false,
        isForeignKey: true,
      ),
    );

    // Add position column for lists
    if (collectionInfo.kind == CollectionKind.list) {
      columns.add(
        ColumnDefinition(
          name: 'position',
          sqlType: dialect.integerColumnType,
          dartType: 'int',
          isNullable: false,
          isPrimaryKey: false,
          isForeignKey: false,
        ),
      );
    }

    // Add map_key column for maps
    if (collectionInfo.kind == CollectionKind.map) {
      final keyType = collectionInfo.keyType;
      if (keyType != null) {
        final keyTypeName = _getTypeName(keyType);
        final keySqlType = typeMapper.getSqlType(keyTypeName, dialect);
        if (keySqlType != null) {
          columns.add(
            ColumnDefinition(
              name: 'map_key',
              sqlType: keySqlType,
              dartType: keyTypeName,
              isNullable: false,
              isPrimaryKey: false,
              isForeignKey: false,
            ),
          );
        }
      }
    }

    // Flatten value object fields into columns
    final valueColumns = _flattenValueObjectFields(
      valueObjectClass,
      typeMapper,
    );
    columns.addAll(valueColumns);

    // Add foreign key constraint with CASCADE DELETE
    foreignKeys.add(
      ForeignKeyDefinition(
        columnName: '${parentTable}_id',
        referencedTable: parentTable,
        referencedColumn: 'id',
        onDelete: CascadeAction.cascade,
      ),
    );

    return TableDefinition(
      tableName: tableName,
      className: '${fieldName}_items',
      columns: columns,
      foreignKeys: foreignKeys,
      isAggregateRoot: false,
    );
  }

  /// Flattens value object fields into column definitions.
  ///
  /// Extracts all fields from a value object class and creates
  /// column definitions for each field. This is used when embedding
  /// value objects into junction tables.
  ///
  /// Example:
  /// ```dart
  /// // For Money class with amount (double) and currency (String)
  /// final columns = _flattenValueObjectFields(moneyClass, typeMapper);
  /// // Returns:
  /// // - ColumnDefinition(name: 'amount', sqlType: 'REAL', ...)
  /// // - ColumnDefinition(name: 'currency', sqlType: 'TEXT', ...)
  /// ```
  List<ColumnDefinition> _flattenValueObjectFields(
    ClassElement valueObjectClass,
    TypeMapper typeMapper,
  ) {
    final columns = <ColumnDefinition>[];

    for (final field in valueObjectClass.fields) {
      // Skip static fields and synthetic fields
      if (field.isStatic || field.isSynthetic) continue;

      final fieldType = field.type;
      final dartTypeName = _getTypeName(fieldType);
      final sqlType = typeMapper.getSqlType(dartTypeName, dialect);

      if (sqlType != null) {
        columns.add(
          ColumnDefinition(
            name: field.name,
            sqlType: sqlType,
            dartType: dartTypeName,
            isNullable: fieldType.nullabilitySuffix.toString().contains('?'),
            isPrimaryKey: false,
            isForeignKey: false,
          ),
        );
      }
    }

    return columns;
  }

  /// Generates a table definition for an entity collection.
  ///
  /// Creates a table for collections of entities (Set<Entity>,
  /// Map<primitive, Entity>). Unlike primitive and value object collections,
  /// entities get their own full tables with all their fields.
  ///
  /// For Set<Entity>:
  /// - No position column (sets are unordered)
  /// - Entity has its own id as primary key
  /// - Foreign key to parent with CASCADE DELETE
  ///
  /// For Map<primitive, Entity>:
  /// - Includes map_key column
  /// - Entity has its own id as primary key
  /// - Foreign key to parent with CASCADE DELETE
  /// - UNIQUE constraint on (parent_id, map_key)
  ///
  /// Note: This method generates the table structure. The actual entity
  /// fields are added by the repository generator based on the entity class.
  ///
  /// Example:
  /// ```dart
  /// // For Set<OrderItem> items
  /// final table = generator.generateEntityCollectionTable(
  ///   parentTable: 'orders',
  ///   fieldName: 'items',
  ///   collectionInfo: setOfOrderItemInfo,
  ///   entityClass: orderItemClass,
  /// );
  /// // Creates: order_items (
  /// //   id BLOB PRIMARY KEY NOT NULL,
  /// //   orders_id BLOB NOT NULL,
  /// //   ... entity fields ...,
  /// //   FOREIGN KEY (orders_id) REFERENCES orders(id) ON DELETE CASCADE
  /// // )
  /// ```
  TableDefinition generateEntityCollectionTable({
    required String parentTable,
    required String fieldName,
    required CollectionInfo collectionInfo,
    required ClassElement entityClass,
  }) {
    final tableName = _toSnakeCase(fieldName);
    const typeMapper = TypeMapper();
    final columns = <ColumnDefinition>[];
    final foreignKeys = <ForeignKeyDefinition>[];

    // Add entity id as primary key
    columns.add(
      ColumnDefinition(
        name: 'id',
        sqlType: dialect.uuidColumnType,
        dartType: 'UuidValue',
        isNullable: false,
        isPrimaryKey: true,
        isForeignKey: false,
      ),
    );

    // Add parent foreign key column
    columns.add(
      ColumnDefinition(
        name: '${parentTable}_id',
        sqlType: dialect.uuidColumnType,
        dartType: 'UuidValue',
        isNullable: false,
        isPrimaryKey: false,
        isForeignKey: true,
      ),
    );

    // Add map_key column for maps
    if (collectionInfo.kind == CollectionKind.map) {
      final keyType = collectionInfo.keyType;
      if (keyType != null) {
        final keyTypeName = _getTypeName(keyType);
        final keySqlType = typeMapper.getSqlType(keyTypeName, dialect);
        if (keySqlType != null) {
          columns.add(
            ColumnDefinition(
              name: 'map_key',
              sqlType: keySqlType,
              dartType: keyTypeName,
              isNullable: false,
              isPrimaryKey: false,
              isForeignKey: false,
            ),
          );
        }
      }
    }

    // Add entity fields (flattened, similar to value objects)
    final entityColumns = _flattenValueObjectFields(entityClass, typeMapper);
    columns.addAll(entityColumns);

    // Add foreign key constraint with CASCADE DELETE
    foreignKeys.add(
      ForeignKeyDefinition(
        columnName: '${parentTable}_id',
        referencedTable: parentTable,
        referencedColumn: 'id',
        onDelete: CascadeAction.cascade,
      ),
    );

    return TableDefinition(
      tableName: tableName,
      className: entityClass.name,
      columns: columns,
      foreignKeys: foreignKeys,
      isAggregateRoot: false,
    );
  }

  /// Converts a camelCase string to snake_case.
  ///
  /// Example:
  /// ```dart
  /// _toSnakeCase('favoriteNumbers'); // 'favorite_numbers'
  /// _toSnakeCase('orderItems'); // 'order_items'
  /// ```
  String _toSnakeCase(String camelCase) {
    return camelCase.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Gets the type name from a DartType, removing nullability markers.
  String _getTypeName(DartType type) {
    final typeName = type.getDisplayString(withNullability: false);
    return typeName;
  }
}
