/// Code generator for SQLite repository implementations.
library;

// ignore_for_file: deprecated_member_use, avoid_redundant_argument_values

import 'package:analyzer/dart/element/element.dart' hide ElementKind;
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:dddart_repository_sqlite/src/annotations/generate_sqlite_repository.dart';
import 'package:dddart_repository_sqlite/src/dialect/sqlite_dialect.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function for the SQLite repository generator.
///
/// This function is referenced in build.yaml and creates the builder
/// that generates SQLite repository implementations.
///
/// The builder uses [SharedPartBuilder] to generate `.sqlite_repository.g.part`
/// files for classes annotated with [@GenerateSqliteRepository].
Builder sqliteRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [SqliteRepositoryGenerator()],
    'sqlite_repository',
  );
}

/// Generator for SQLite repository implementations.
///
/// This generator processes classes annotated with [GenerateSqliteRepository]
/// and generates SQLite repository implementations with full normalization,
/// multi-table persistence, and value object embedding.
class SqliteRepositoryGenerator
    extends GeneratorForAnnotation<GenerateSqliteRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateSqliteRepository.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateSqliteRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateSqliteRepository.',
        element: element,
      );
    }

    // Extract configuration from annotation
    final tableName = _extractTableName(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    // Analyze object graph to generate table definitions
    final tables = _analyzeObjectGraph(classElement, tableName);

    // Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - generate concrete class
      return _generateConcreteRepository(
        className,
        tableName,
        classElement,
        tables,
      );
    }

    // Analyze interface to determine if abstract base is needed
    final interfaceMethods = _getInterfaceMethods(customInterface);
    final baseRepositoryMethods = {'getById', 'save', 'deleteById'};
    final objectMethods = {
      'toString',
      'hashCode',
      'noSuchMethod',
      'runtimeType',
      '==',
      'hash',
      'hashAll',
      'hashAllUnordered',
    };
    final customMethods = interfaceMethods
        .where(
          (m) =>
              !baseRepositoryMethods.contains(m.name) &&
              !objectMethods.contains(m.name) &&
              !m.isOperator &&
              !m.isStatic,
        )
        .toList();

    if (customMethods.isEmpty) {
      // Interface only has base Repository methods - generate concrete class
      return _generateConcreteRepository(
        className,
        tableName,
        classElement,
        tables,
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - generate abstract base class
      return _generateAbstractBaseRepository(
        className,
        tableName,
        classElement,
        tables,
        implements: customInterface,
        abstractMethods: customMethods,
      );
    }
  }

  /// Validates that a class extends AggregateRoot.
  ///
  /// Walks the inheritance hierarchy to find AggregateRoot.
  bool _extendsAggregateRoot(ClassElement element) {
    ClassElement? current = element;
    while (current != null) {
      if (current.name == 'AggregateRoot') return true;
      final supertype = current.supertype;
      if (supertype == null) break;
      current = supertype.element as ClassElement?;
    }
    return false;
  }

  /// Validates that a class has the @Serializable annotation.
  bool _hasSerializableAnnotation(ClassElement element) {
    return element.metadata.any((annotation) {
      final annotationElement = annotation.element;
      return annotationElement is ConstructorElement &&
          annotationElement.enclosingElement.name == 'Serializable';
    });
  }

  /// Extracts the table name from the annotation or generates a default.
  ///
  /// If `tableName` is provided in the annotation, uses that value.
  /// Otherwise, converts the class name to snake_case.
  String _extractTableName(ConstantReader annotation, String className) {
    final tableName = annotation.peek('tableName')?.stringValue;
    return tableName ?? _toSnakeCase(className);
  }

  /// Extracts the custom interface type from the annotation.
  ///
  /// Returns null if no custom interface is specified.
  InterfaceType? _extractImplementsInterface(ConstantReader annotation) {
    final implementsField = annotation.peek('implements');
    if (implementsField == null || implementsField.isNull) return null;

    return implementsField.typeValue as InterfaceType?;
  }

  /// Gets all methods from an interface type, including inherited methods.
  List<MethodElement> _getInterfaceMethods(InterfaceType interfaceType) {
    final methods = <MethodElement>[];

    // Get methods from the interface itself
    methods.addAll(interfaceType.methods);

    // Get methods from all superinterfaces (including Repository<T>)
    for (final supertype in interfaceType.allSupertypes) {
      final supertypeName = supertype.element.name;
      // Skip Object and system classes
      if (supertypeName == 'Object' ||
          supertypeName.startsWith('_') ||
          supertype.element.library.name.startsWith('dart.')) {
        continue;
      }
      methods.addAll(supertype.methods);
    }

    return methods;
  }

  /// Converts a camelCase or PascalCase string to snake_case.
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }

  /// Analyzes the object graph and generates table definitions.
  ///
  /// Uses RelationshipAnalyzer to discover all types referenced by the
  /// aggregate root, then generates TableDefinitions for each type.
  /// Returns tables ordered by dependencies (dependencies first).
  Map<String, TableDefinition> _analyzeObjectGraph(
    ClassElement aggregateRoot,
    String aggregateTableName,
  ) {
    // Clear the entity-to-field mapping for this aggregate
    _entityToFieldName.clear();
    _collectionFields.clear();

    _analyzer = const RelationshipAnalyzer();
    const collectionAnalyzer = CollectionAnalyzer();
    const typeMapper = TypeMapper();
    const dialect = SqliteDialect();

    // Discover all types in dependency order
    final discoveredTypes = _analyzer.analyzeAggregate(aggregateRoot);

    // Discover collection fields in the aggregate root
    for (final field in aggregateRoot.fields) {
      if (field.isStatic || field.isSynthetic) continue;

      // Validate collection types before analyzing
      try {
        collectionAnalyzer.validateCollectionType(field.type);
      } catch (e) {
        if (e is UnsupportedError) {
          throw InvalidGenerationSourceError(
            'Unsupported collection type in field "${field.name}":\n${e.message}',
            element: field,
          );
        }
        rethrow;
      }

      final collectionInfo = collectionAnalyzer.analyzeCollection(field);
      if (collectionInfo != null) {
        _collectionFields[field.name] = collectionInfo;
      }
    }

    // Generate table definitions for each type
    final tables = <String, TableDefinition>{};

    for (final classElement in discoveredTypes) {
      // Skip value objects - they are embedded, not stored in separate tables
      if (_analyzer.isValueObject(classElement)) {
        continue;
      }

      // Use the provided table name for the aggregate root, snake_case for others
      final tableName = classElement == aggregateRoot
          ? aggregateTableName
          : _toSnakeCase(classElement.name);

      final tableDef = _generateTableDefinition(
        classElement,
        _analyzer,
        typeMapper,
        dialect,
        tableName,
      );
      tables[classElement.name] = tableDef;
    }

    // Add parent foreign keys to entity tables
    _addParentForeignKeys(tables, aggregateRoot, aggregateTableName, _analyzer);

    return tables;
  }

  /// Maps entity class names to their JSON field names in the aggregate.
  final _entityToFieldName = <String, String>{};

  /// Maps collection field names to their collection information.
  final _collectionFields = <String, CollectionInfo>{};

  /// The relationship analyzer instance.
  late RelationshipAnalyzer _analyzer;

  /// Adds parent foreign key columns to entity tables.
  ///
  /// For each entity that's part of a collection field in the aggregate,
  /// adds a foreign key column back to the parent aggregate.
  void _addParentForeignKeys(
    Map<String, TableDefinition> tables,
    ClassElement aggregateRoot,
    String aggregateTableName,
    RelationshipAnalyzer analyzer,
  ) {
    // Find all List<Entity>, Set<Entity>, and Map<K, Entity> fields in the aggregate
    for (final field in aggregateRoot.fields) {
      ClassElement? entityClass;

      // Check for List<Entity>
      if (field.type.isDartCoreList) {
        final elementType = (field.type as InterfaceType).typeArguments.first;
        if (elementType is InterfaceType) {
          final element = elementType.element;
          if (element is ClassElement && !_analyzer.isValueObject(element)) {
            entityClass = element;
          }
        }
      }

      // Check for Set<Entity>
      if (field.type.isDartCoreSet) {
        final elementType = (field.type as InterfaceType).typeArguments.first;
        if (elementType is InterfaceType) {
          final element = elementType.element;
          if (element is ClassElement && !_analyzer.isValueObject(element)) {
            entityClass = element;
          }
        }
      }

      // Check for Map<K, Entity>
      if (field.type.isDartCoreMap) {
        final typeArgs = (field.type as InterfaceType).typeArguments;
        if (typeArgs.length == 2) {
          final valueType = typeArgs[1];
          if (valueType is InterfaceType) {
            final element = valueType.element;
            if (element is ClassElement && !_analyzer.isValueObject(element)) {
              entityClass = element;
            }
          }
        }
      }

      if (entityClass != null) {
        // Store the mapping from entity class to field name
        // (use the first field name if entity is in multiple collections)
        if (!_entityToFieldName.containsKey(entityClass.name)) {
          _entityToFieldName[entityClass.name] = field.name;
        }

        // This is an entity in a collection - add parent FK
        final entityTable = tables[entityClass.name];
        if (entityTable != null) {
          final fkColumnName = '${aggregateTableName.replaceAll('_', '')}_id';

          // Check if FK column already exists (entity used in multiple collections)
          final fkExists =
              entityTable.columns.any((c) => c.name == fkColumnName);

          if (!fkExists) {
            // Add foreign key column
            final fkColumn = ColumnDefinition(
              name: fkColumnName,
              sqlType: 'BLOB',
              dartType: 'UuidValue',
              isNullable: false,
              isPrimaryKey: false,
              isForeignKey: true,
            );

            // Add foreign key constraint
            final fk = ForeignKeyDefinition(
              columnName: fkColumnName,
              referencedTable: aggregateTableName,
              referencedColumn: 'id',
              onDelete: CascadeAction.cascade,
            );

            // Create new table definition with added column and FK
            final updatedTable = TableDefinition(
              tableName: entityTable.tableName,
              className: entityTable.className,
              columns: [...entityTable.columns, fkColumn],
              foreignKeys: [...entityTable.foreignKeys, fk],
              isAggregateRoot: false,
            );

            tables[entityClass.name] = updatedTable;
          }
        }
      }
    }
  }

  /// Gets all fields from a class including inherited fields.
  List<FieldElement> _getAllFields(ClassElement classElement) {
    final fields = <FieldElement>[];
    final seenFields = <String>{};

    // Add fields from the class itself
    for (final field in classElement.fields) {
      // Skip synthetic fields (getters without backing fields)
      if (field.isSynthetic) continue;

      if (!seenFields.contains(field.name)) {
        fields.add(field);
        seenFields.add(field.name);
      }
    }

    // Add fields from superclasses
    var currentClass = classElement.supertype?.element;
    while (currentClass != null) {
      // Stop at Object or if we've reached a non-class element
      if (currentClass.name == 'Object') break;

      for (final field in currentClass.fields) {
        // Skip synthetic fields (getters without backing fields)
        if (field.isSynthetic) continue;

        if (!seenFields.contains(field.name)) {
          fields.add(field);
          seenFields.add(field.name);
        }
      }

      currentClass = currentClass.supertype?.element;
    }

    return fields;
  }

  /// Generates a TableDefinition for a class.
  TableDefinition _generateTableDefinition(
    ClassElement classElement,
    RelationshipAnalyzer analyzer,
    TypeMapper typeMapper,
    SqlDialect dialect,
    String tableName,
  ) {
    final columns = <ColumnDefinition>[];
    final foreignKeys = <ForeignKeyDefinition>[];

    // Get all fields including inherited ones
    final allFields = _getAllFields(classElement);

    // Add columns for all fields
    for (final field in allFields) {
      // Skip static fields
      if (field.isStatic) continue;

      final fieldType = field.type;
      final fieldName = field.name;

      // Handle List<T> - these become separate tables with FKs
      if (fieldType.isDartCoreList) {
        // Skip - will be handled as a separate table
        continue;
      }

      // Check if it's a value object
      final referencedClass = _getReferencedClass(fieldType);
      if (referencedClass != null && _analyzer.isValueObject(referencedClass)) {
        // Special case: UuidValue should be stored as BLOB, not embedded
        if (referencedClass.name == 'UuidValue') {
          final column = ColumnDefinition(
            name: fieldName,
            sqlType: 'BLOB',
            dartType: 'UuidValue',
            isNullable:
                fieldType.nullabilitySuffix.toString().contains('question'),
            isPrimaryKey: fieldName == 'id',
            isForeignKey: false,
          );
          columns.add(column);
          continue;
        }

        // Embed value object fields with prefixed column names
        final embeddedColumns = _generateEmbeddedColumns(
          fieldName,
          referencedClass,
          typeMapper,
          dialect,
          fieldType.nullabilitySuffix.toString().contains('question'),
        );
        columns.addAll(embeddedColumns);
        continue;
      }

      // Check if it's an entity or aggregate reference
      if (referencedClass != null &&
          (_analyzer.isEntity(referencedClass) ||
              _analyzer.isAggregateRoot(referencedClass))) {
        // Add foreign key column
        final fkColumn = ColumnDefinition(
          name: '${fieldName}_id',
          sqlType: 'BLOB',
          dartType: 'UuidValue',
          isNullable:
              fieldType.nullabilitySuffix.toString().contains('question'),
          isPrimaryKey: false,
          isForeignKey: true,
        );
        columns.add(fkColumn);

        // Add foreign key constraint
        final cascadeAction = _analyzer.isAggregateRoot(referencedClass)
            ? CascadeAction.restrict // Don't cascade across aggregates
            : CascadeAction.cascade; // Cascade within aggregate

        foreignKeys.add(
          ForeignKeyDefinition(
            columnName: '${fieldName}_id',
            referencedTable: _toSnakeCase(referencedClass.name),
            referencedColumn: 'id',
            onDelete: cascadeAction,
          ),
        );
        continue;
      }

      // Handle primitive types
      final dartTypeName = fieldType.getDisplayString(withNullability: false);
      final sqlType = typeMapper.getSqlType(dartTypeName, dialect);

      if (sqlType != null) {
        columns.add(
          ColumnDefinition(
            name: fieldName,
            sqlType: sqlType,
            dartType: dartTypeName,
            isNullable:
                fieldType.nullabilitySuffix.toString().contains('question'),
            isPrimaryKey: fieldName == 'id',
            isForeignKey: false,
          ),
        );
      }
    }

    // Ensure we have an id column (primary key)
    if (!columns.any((c) => c.isPrimaryKey)) {
      columns.insert(
        0,
        const ColumnDefinition(
          name: 'id',
          sqlType: 'BLOB',
          dartType: 'UuidValue',
          isNullable: false,
          isPrimaryKey: true,
          isForeignKey: false,
        ),
      );
    }

    return TableDefinition(
      tableName: tableName,
      className: classElement.name,
      columns: columns,
      foreignKeys: foreignKeys,
      isAggregateRoot: _analyzer.isAggregateRoot(classElement),
    );
  }

  /// Generates embedded columns for a value object.
  ///
  /// Value objects are flattened into the parent table with prefixed column names.
  List<ColumnDefinition> _generateEmbeddedColumns(
    String prefix,
    ClassElement valueObjectClass,
    TypeMapper typeMapper,
    SqlDialect dialect,
    bool isNullable,
  ) {
    final columns = <ColumnDefinition>[];

    for (final field in valueObjectClass.fields) {
      if (field.isStatic) continue;

      final fieldType = field.type;
      final dartTypeName = fieldType.getDisplayString(withNullability: false);
      final sqlType = typeMapper.getSqlType(dartTypeName, dialect);

      if (sqlType != null) {
        columns.add(
          ColumnDefinition(
            name: '${prefix}_${field.name}',
            sqlType: sqlType,
            dartType: dartTypeName,
            isNullable: isNullable ||
                fieldType.nullabilitySuffix.toString().contains('question'),
            isPrimaryKey: false,
            isForeignKey: false,
          ),
        );
      }
    }

    return columns;
  }

  /// Extracts the ClassElement from a DartType.
  ClassElement? _getReferencedClass(DartType type) {
    // Handle List<T> - extract T
    if (type is InterfaceType && type.isDartCoreList) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final elementType = typeArgs.first;
        if (elementType is InterfaceType) {
          final element = elementType.element;
          if (element is ClassElement) {
            return element;
          }
        }
      }
      return null;
    }

    // Handle direct class reference
    if (type is InterfaceType) {
      final element = type.element;
      if (element is ClassElement) {
        return element;
      }
    }

    return null;
  }

  /// Generates a concrete repository class implementation.
  String _generateConcreteRepository(
    String className,
    String tableName,
    ClassElement classElement,
    Map<String, TableDefinition> tables, {
    InterfaceType? implements,
  }) {
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated SQLite repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class provides CRUD operations with full normalization,',
    );
    buffer.writeln('/// multi-table persistence, and value object embedding.');
    buffer.writeln('class ${className}SqliteRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - An open SQLite database connection.');
    buffer.writeln('  ${className}SqliteRepository(this._connection);');
    buffer.writeln();

    // Fields and getters
    buffer.writeln('  /// The SQLite database connection.');
    buffer.writeln('  final SqliteConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for SQLite.');
    buffer.writeln('  final _dialect = SqliteDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables, className, tableName));
    buffer.writeln();

    // Generate CRUD methods
    buffer.writeln(_generateGetByIdMethod(className, tableName, tables));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className, tableName, tables));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className, tableName));
    buffer.writeln();

    // Generate helper methods
    buffer.writeln(_generateHelperMethods(tables, tableName, className));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapSqliteExceptionMethod());

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates the createTables method.
  String _generateCreateTablesMethod(
    Map<String, TableDefinition> tables,
    String className,
    String tableName,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('  /// Creates all tables for this aggregate.');
    buffer.writeln('  ///');
    buffer
        .writeln('  /// This method should be called once during application');
    buffer.writeln('  /// initialization to ensure all required tables exist.');
    buffer.writeln('  ///');
    buffer.writeln(
      '  /// Uses CREATE TABLE IF NOT EXISTS, so it is safe to call',
    );
    buffer.writeln('  /// multiple times.');
    buffer.writeln('  Future<void> createTables() async {');
    buffer.writeln('    await _connection.transaction(() async {');

    // Generate CREATE TABLE statements in dependency order
    // Tables are already in dependency order from _analyzeObjectGraph
    for (final table in tables.values) {
      buffer.writeln('      // Create table: ${table.tableName}');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln("        '''");
      buffer.writeln(_generateCreateTableSql(table));
      buffer.writeln("        ''',");
      buffer.writeln('      );');
      buffer.writeln();
    }

    // Generate CREATE TABLE statements for collection junction tables
    for (final entry in _collectionFields.entries) {
      final fieldName = entry.key;
      final collectionInfo = entry.value;
      final junctionTableName = '${tableName}_$fieldName';

      buffer
          .writeln('      // Create junction table for collection: $fieldName');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln("        '''");
      buffer.writeln(
        _generateCollectionTableSql(
          junctionTableName,
          tableName,
          collectionInfo,
          _analyzer,
        ),
      );
      buffer.writeln("        ''',");
      buffer.writeln('      );');
      buffer.writeln();
    }

    buffer.writeln('    });');
    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Generates CREATE TABLE SQL for a table definition.
  String _generateCreateTableSql(TableDefinition table) {
    final buffer = StringBuffer();
    buffer.writeln('CREATE TABLE IF NOT EXISTS "${table.tableName}" (');

    // Add columns
    final columnDefs = <String>[];
    for (final column in table.columns) {
      final parts = <String>[
        '"${column.name}"',
        column.sqlType,
      ];

      if (column.isPrimaryKey) {
        parts.add('PRIMARY KEY');
      }

      if (!column.isNullable) {
        parts.add('NOT NULL');
      }

      columnDefs.add('  ${parts.join(' ')}');
    }

    buffer.write(columnDefs.join(',\n'));

    // Add foreign key constraints
    if (table.foreignKeys.isNotEmpty) {
      buffer.writeln(',');
      final fkDefs = <String>[];
      for (final fk in table.foreignKeys) {
        final onDelete = _cascadeActionToSql(fk.onDelete);
        fkDefs.add(
          '  FOREIGN KEY ("${fk.columnName}") '
          'REFERENCES "${fk.referencedTable}"("${fk.referencedColumn}") '
          'ON DELETE $onDelete',
        );
      }
      buffer.write(fkDefs.join(',\n'));
    }

    buffer.write('\n)');

    return buffer.toString();
  }

  /// Converts CascadeAction to SQL string.
  String _cascadeActionToSql(CascadeAction action) {
    switch (action) {
      case CascadeAction.cascade:
        return 'CASCADE';
      case CascadeAction.setNull:
        return 'SET NULL';
      case CascadeAction.restrict:
        return 'RESTRICT';
    }
  }

  /// Generates CREATE TABLE SQL for a collection junction table.
  String _generateCollectionTableSql(
    String tableName,
    String parentTableName,
    CollectionInfo collectionInfo,
    RelationshipAnalyzer analyzer,
  ) {
    const dialect = SqliteDialect();
    const typeMapper = TypeMapper();

    final buffer = StringBuffer();
    buffer.writeln('CREATE TABLE IF NOT EXISTS "$tableName" (');

    final columnDefs = <String>[];

    // Add parent foreign key column (use full table name with underscores)
    final parentFkColumn = '${parentTableName}_id';
    columnDefs.add('  "$parentFkColumn" BLOB NOT NULL');

    // Add position column for lists
    if (collectionInfo.kind == CollectionKind.list) {
      columnDefs.add('  "position" INTEGER NOT NULL');
    }

    // Add map_key column for maps
    if (collectionInfo.kind == CollectionKind.map) {
      // Get the key type from the collection info
      final keyType = collectionInfo.keyType;
      if (keyType != null) {
        final keyTypeName = keyType.getDisplayString(withNullability: false);
        final keySqlType =
            typeMapper.getSqlType(keyTypeName, dialect) ?? 'TEXT';
        columnDefs.add('  "map_key" $keySqlType NOT NULL');
      }
    }

    // Add value column(s) based on element kind
    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        // Single value column for primitives
        final elementTypeName =
            collectionInfo.elementType.getDisplayString(withNullability: false);
        final sqlType =
            typeMapper.getSqlType(elementTypeName, dialect) ?? 'TEXT';
        // Check if element type is nullable
        final isElementNullable = collectionInfo.elementType.nullabilitySuffix
            .toString()
            .contains('question');
        columnDefs.add(
          '  "value" $sqlType${isElementNullable ? '' : ' NOT NULL'}',
        );

      case ElementKind.value:
        // Flattened value object fields
        if (collectionInfo.elementType is InterfaceType) {
          final interfaceType = collectionInfo.elementType as InterfaceType;
          final valueClass = interfaceType.element;
          if (valueClass is ClassElement) {
            for (final field in valueClass.fields) {
              // Skip static fields, synthetic fields, and the props getter
              if (field.isStatic ||
                  field.isSynthetic ||
                  field.name == 'props') {
                continue;
              }
              final fieldTypeName =
                  field.type.getDisplayString(withNullability: false);
              final sqlType =
                  typeMapper.getSqlType(fieldTypeName, dialect) ?? 'TEXT';
              final isNullable =
                  field.type.nullabilitySuffix.toString().contains('question');
              columnDefs.add(
                '  "${field.name}" $sqlType${isNullable ? '' : ' NOT NULL'}',
              );
            }
          }
        }

      case ElementKind.entity:
        // Entity fields (similar to value objects but with id)
        if (collectionInfo.elementType is InterfaceType) {
          final interfaceType = collectionInfo.elementType as InterfaceType;
          final entityClass = interfaceType.element;
          if (entityClass is ClassElement) {
            // Add id column first
            columnDefs.add('  "id" BLOB PRIMARY KEY NOT NULL');

            // Get all fields including inherited ones
            final allFields = _getAllFields(entityClass);

            // Add other entity fields
            for (final field in allFields) {
              // Skip static fields, id, and props getter
              if (field.isStatic ||
                  field.name == 'id' ||
                  field.name == 'props') {
                continue;
              }

              // Check if field is a value object that needs flattening
              final fieldType = field.type;
              if (fieldType is InterfaceType) {
                final fieldClass = fieldType.element;
                if (fieldClass is ClassElement &&
                    _analyzer.isValueObject(fieldClass)) {
                  // Special case: UuidValue should be stored as BLOB, not flattened
                  if (fieldClass.name == 'UuidValue') {
                    final isNullable = field.type.nullabilitySuffix
                        .toString()
                        .contains('question');
                    columnDefs.add(
                      '  "${field.name}" BLOB${isNullable ? '' : ' NOT NULL'}',
                    );
                    continue;
                  }

                  // Flatten value object fields with prefix
                  for (final valueField in fieldClass.fields) {
                    if (valueField.isStatic ||
                        valueField.isSynthetic ||
                        valueField.name == 'props') {
                      continue;
                    }
                    final valueFieldTypeName = valueField.type
                        .getDisplayString(withNullability: false);
                    final sqlType =
                        typeMapper.getSqlType(valueFieldTypeName, dialect) ??
                            'TEXT';
                    final isNullable = valueField.type.nullabilitySuffix
                        .toString()
                        .contains('question');
                    columnDefs.add(
                      '  "${field.name}_${valueField.name}" $sqlType${isNullable ? '' : ' NOT NULL'}',
                    );
                  }
                  continue;
                }
              }

              // Regular field (not a value object)
              final fieldTypeName =
                  field.type.getDisplayString(withNullability: false);
              final sqlType =
                  typeMapper.getSqlType(fieldTypeName, dialect) ?? 'TEXT';
              final isNullable =
                  field.type.nullabilitySuffix.toString().contains('question');
              columnDefs.add(
                '  "${field.name}" $sqlType${isNullable ? '' : ' NOT NULL'}',
              );
            }
          }
        }
    }

    buffer.write(columnDefs.join(',\n'));

    // Add foreign key constraint
    buffer.writeln(',');
    buffer.write(
      '  FOREIGN KEY ("$parentFkColumn") '
      'REFERENCES "$parentTableName"("id") '
      'ON DELETE CASCADE',
    );

    // Add unique constraints
    if (collectionInfo.kind == CollectionKind.list) {
      buffer.writeln(',');
      buffer.write('  UNIQUE ($parentFkColumn, position)');
    } else if (collectionInfo.kind == CollectionKind.set &&
        collectionInfo.elementKind == ElementKind.primitive) {
      buffer.writeln(',');
      buffer.write('  UNIQUE ($parentFkColumn, value)');
    } else if (collectionInfo.kind == CollectionKind.map) {
      buffer.writeln(',');
      buffer.write('  UNIQUE ($parentFkColumn, map_key)');
    }

    buffer.write('\n)');

    return buffer.toString();
  }

  /// Generates an abstract base repository class.
  String _generateAbstractBaseRepository(
    String className,
    String tableName,
    ClassElement classElement,
    Map<String, TableDefinition> tables, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated abstract base SQLite repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This abstract class implements the base Repository<$className> methods',
    );
    buffer.writeln(
      '/// and declares custom methods as abstract. Extend this class and',
    );
    buffer.writeln('/// implement the abstract methods.');
    buffer.writeln(
      'abstract class ${className}SqliteRepositoryBase implements ${implements.element.name} {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - An open SQLite database connection.');
    buffer.writeln('  ${className}SqliteRepositoryBase(this._connection);');
    buffer.writeln();

    // Protected fields for subclass access
    buffer.writeln('  /// The SQLite database connection (protected).');
    buffer.writeln('  final SqliteConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for SQLite (protected).');
    buffer.writeln('  final _dialect = SqliteDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer (protected).');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables, className, tableName));
    buffer.writeln();

    // Generate CRUD methods
    buffer.writeln(_generateGetByIdMethod(className, tableName, tables));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className, tableName, tables));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className, tableName));
    buffer.writeln();

    // Generate helper methods
    buffer.writeln(_generateHelperMethods(tables, tableName, className));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapSqliteExceptionMethod());
    buffer.writeln();

    // Abstract method declarations for custom methods
    if (abstractMethods.isNotEmpty) {
      buffer.writeln('  // Custom methods (must be implemented by subclass)');
      buffer.writeln();
      for (final method in abstractMethods) {
        buffer.writeln('  @override');
        buffer.writeln('  ${_generateMethodSignature(method)};');
        buffer.writeln();
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(
    String className,
    String tableName,
    Map<String, TableDefinition> tables,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('  @override');
    buffer.writeln('  Future<$className> getById(UuidValue id) async {');
    buffer.writeln('    return await _connection.transaction(() async {');
    buffer.writeln('      try {');
    buffer.writeln('        // Query the aggregate root table');
    buffer.writeln('        final rows = await _connection.query(');
    buffer.writeln('          \'SELECT * FROM "$tableName" WHERE "id" = ?\',');
    buffer.writeln('          [_dialect.encodeUuid(id)],');
    buffer.writeln('        );');
    buffer.writeln();
    buffer.writeln('        if (rows.isEmpty) {');
    buffer.writeln('          throw RepositoryException(');
    buffer.writeln("            '$className with ID \$id not found',");
    buffer.writeln('            type: RepositoryExceptionType.notFound,');
    buffer.writeln('          );');
    buffer.writeln('        }');
    buffer.writeln();
    buffer.writeln('        final row = rows.first;');
    buffer.writeln('        final json = _rowToJson(row);');
    buffer.writeln();

    // Generate load logic for nested entities (if any)
    // Skip entities that are part of collections
    final collectionEntityClasses = <String>{};
    for (final collectionInfo in _collectionFields.values) {
      if (collectionInfo.elementKind == ElementKind.entity) {
        if (collectionInfo.elementType is InterfaceType) {
          final interfaceType = collectionInfo.elementType as InterfaceType;
          final className = interfaceType.element.name;
          collectionEntityClasses.add(className);
        }
      }
    }

    final entityTables = tables.values
        .where(
          (t) =>
              t.tableName != tableName &&
              !collectionEntityClasses.contains(t.className),
        )
        .toList();

    if (entityTables.isNotEmpty) {
      buffer.writeln('        // Load nested entities');
      for (final entityTable in entityTables) {
        buffer.writeln(
          "        json['${_findJsonKeyForTable(entityTable)}'] = await _load${_toPascalCase(entityTable.tableName)}(id);",
        );
      }
      buffer.writeln();
    }

    // Generate load logic for collections (if any)
    if (_collectionFields.isNotEmpty) {
      buffer.writeln('        // Load collections');
      for (final fieldName in _collectionFields.keys) {
        buffer.writeln(
          "        json['$fieldName'] = await _load${_toPascalCase(fieldName)}(id);",
        );
      }
      buffer.writeln();
    }

    buffer.writeln('        return _serializer.fromJson(json);');
    buffer.writeln('      } on RepositoryException {');
    buffer.writeln('        rethrow;');
    buffer.writeln('      } catch (e) {');
    buffer.writeln("        throw _mapSqliteException(e, 'getById');");
    buffer.writeln('      }');
    buffer.writeln('    });');
    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(
    String className,
    String tableName,
    Map<String, TableDefinition> tables,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> save($className aggregate) async {');
    buffer.writeln('    await _connection.transaction(() async {');
    buffer.writeln('      try {');
    buffer.writeln('        // Serialize aggregate to JSON');
    buffer.writeln('        final json = _serializer.toJson(aggregate);');
    buffer.writeln();

    // Generate save logic for aggregate root FIRST
    // Skip entities that are part of collections
    final collectionEntityClasses = <String>{};
    for (final collectionInfo in _collectionFields.values) {
      if (collectionInfo.elementKind == ElementKind.entity) {
        if (collectionInfo.elementType is InterfaceType) {
          final interfaceType = collectionInfo.elementType as InterfaceType;
          final className = interfaceType.element.name;
          collectionEntityClasses.add(className);
        }
      }
    }

    final allEntityTables =
        tables.values.where((t) => t.tableName != tableName).toList();
    final entityTables = allEntityTables
        .where((t) => !collectionEntityClasses.contains(t.className))
        .toList();

    buffer.writeln(
      '        // Save aggregate root first (required for foreign key constraints)',
    );

    // Build list of keys to exclude (entity tables + collection fields)
    final excludeKeys = <String>[];
    for (final entityTable in allEntityTables) {
      excludeKeys.add("'${_findJsonKeyForTable(entityTable)}'");
    }
    for (final fieldName in _collectionFields.keys) {
      excludeKeys.add("'$fieldName'");
    }

    buffer.writeln(
      '        final rootData = _flattenForTable(json, [${excludeKeys.join(', ')}]);',
    );
    buffer.writeln('        final columns = rootData.keys.toList();');
    buffer.writeln(
      '        final values = columns.map((k) => _encodeValue(rootData[k])).toList();',
    );
    buffer.writeln();
    buffer.writeln(
      "        final placeholders = List.filled(columns.length, '?').join(', ');",
    );
    buffer.writeln('        await _connection.execute(');
    buffer.writeln(
      '          \'INSERT OR REPLACE INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
    );
    buffer.writeln('          values,');
    buffer.writeln('        );');

    // Then save nested entities (if any)
    if (entityTables.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('        // Save nested entities to their tables');
      for (final entityTable in entityTables) {
        buffer.writeln(
          '        await _save${_toPascalCase(entityTable.tableName)}(aggregate, json);',
        );
      }
    }

    // Add collection save calls
    if (_collectionFields.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('        // Save collections to their junction tables');
      for (final fieldName in _collectionFields.keys) {
        buffer.writeln(
          "        await _save${_toPascalCase(fieldName)}(aggregate.id, json['$fieldName']);",
        );
      }
    }

    buffer.writeln('      } catch (e) {');
    buffer.writeln("        throw _mapSqliteException(e, 'save');");
    buffer.writeln('      }');
    buffer.writeln('    });');
    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className, String tableName) {
    return '''
  @override
  Future<void> deleteById(UuidValue id) async {
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT "id" FROM "$tableName" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );

        if (rows.isEmpty) {
          throw RepositoryException(
            '$className with ID \$id not found',
            type: RepositoryExceptionType.notFound,
          );
        }

        // Delete aggregate (CASCADE will handle related entities)
        await _connection.execute(
          'DELETE FROM "$tableName" WHERE "id" = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapSqliteException(e, 'deleteById');
      }
    });
  }''';
  }

  /// Generates the SQLite exception mapping helper method.
  String _generateMapSqliteExceptionMethod() {
    return r'''
  /// Maps SQLite exceptions to RepositoryException types.
  RepositoryException _mapSqliteException(
    Object error,
    String operation,
  ) {
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
  }''';
  }

  /// Generates helper methods for multi-table persistence.
  String _generateHelperMethods(
    Map<String, TableDefinition> tables,
    String rootTableName,
    String className,
  ) {
    final buffer = StringBuffer();

    // Get the root table by className (tables are keyed by class name)
    final rootTable = tables[className];
    if (rootTable == null) {
      throw StateError('Root table for $className not found in tables map');
    }

    // Get entity class names that are part of collections
    final collectionEntityClasses = <String>{};
    for (final collectionInfo in _collectionFields.values) {
      if (collectionInfo.elementKind == ElementKind.entity) {
        // Extract the entity class name from the element type
        if (collectionInfo.elementType is InterfaceType) {
          final interfaceType = collectionInfo.elementType as InterfaceType;
          final className = interfaceType.element.name;
          collectionEntityClasses.add(className);
        }
      }
    }

    // Generate helper methods for each entity table (excluding collection entities)
    final entityTables = tables.values
        .where(
          (t) =>
              t.tableName != rootTableName &&
              !collectionEntityClasses.contains(t.className),
        )
        .toList();

    for (final entityTable in entityTables) {
      buffer.writeln(_generateSaveEntityMethod(entityTable));
      buffer.writeln();
      buffer.writeln(_generateLoadEntityMethod(entityTable));
      buffer.writeln();
    }

    // Generate collection save/load methods
    buffer.writeln(_generateCollectionSaveMethods(className, rootTableName));
    buffer.writeln();
    buffer.writeln(_generateCollectionLoadMethods(className, rootTableName));
    buffer.writeln();

    // Generate utility methods (always generate for consistency)
    buffer.writeln(_generateFlattenForTableMethod());
    buffer.writeln();
    buffer.writeln(_generateRowToJsonMethod());
    buffer.writeln();
    buffer.writeln(_generateFieldTypeMapMethod(rootTable));
    buffer.writeln();
    buffer.writeln(_generateEncodeValueMethod());
    buffer.writeln();
    buffer.writeln(_generateDecodeValueMethod());

    return buffer.toString();
  }

  /// Generates a save method for an entity table.
  String _generateSaveEntityMethod(TableDefinition table) {
    final parentFkColumn = _findParentForeignKeyColumn(table);
    if (parentFkColumn == null) {
      // Skip generating save method for collection entities
      return '';
    }

    final methodName = '_save${_toPascalCase(table.tableName)}';
    final jsonKey = _findJsonKeyForTable(table);

    return '''
  /// Saves ${table.tableName} entities.
  Future<void> $methodName(dynamic aggregate, Map<String, dynamic> json) async {
    // Delete existing entities for this aggregate
    await _connection.execute(
      'DELETE FROM "${table.tableName}" WHERE "$parentFkColumn" = ?',
      [_dialect.encodeUuid(aggregate.id)],
    );

    // Get entities from JSON
    final entitiesJson = json['$jsonKey'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity
    for (final entityJson in entitiesJson) {
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['$parentFkColumn'] = aggregate.id.toString();

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
        'INSERT INTO "${table.tableName}" (\${columns.map((c) => '"\$c"').join(', ')}) VALUES (\$placeholders)',
        values,
      );
    }
  }''';
  }

  /// Generates a load method for an entity table.
  String _generateLoadEntityMethod(TableDefinition table) {
    final parentFkColumn = _findParentForeignKeyColumn(table);
    if (parentFkColumn == null) {
      // Skip generating load method for collection entities
      return '';
    }

    final methodName = '_load${_toPascalCase(table.tableName)}';

    return '''
  /// Loads ${table.tableName} entities for an aggregate.
  Future<List<Map<String, dynamic>>> $methodName(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT * FROM "${table.tableName}" WHERE "$parentFkColumn" = ?',
      [_dialect.encodeUuid(aggregateId)],
    );

    // Convert rows to JSON and remove the parent FK column
    return rows.map((row) {
      final json = _rowToJson(row);
      json.remove('$parentFkColumn');
      return json;
    }).toList();
  }''';
  }

  /// Generates collection save methods for discovered collection fields.
  String _generateCollectionSaveMethods(String className, String tableName) {
    if (_collectionFields.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    for (final entry in _collectionFields.entries) {
      final fieldName = entry.key;
      final collectionInfo = entry.value;

      buffer.writeln(
        _generateCollectionSaveMethod(
          fieldName,
          tableName,
          collectionInfo,
          className,
        ),
      );
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generates collection load methods for discovered collection fields.
  String _generateCollectionLoadMethods(String className, String tableName) {
    if (_collectionFields.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    for (final entry in _collectionFields.entries) {
      final fieldName = entry.key;
      final collectionInfo = entry.value;

      buffer.writeln(
        _generateCollectionLoadMethod(
          fieldName,
          tableName,
          collectionInfo,
          className,
        ),
      );
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generates a save method for a specific collection field.
  String _generateCollectionSaveMethod(
    String fieldName,
    String tableName,
    CollectionInfo collectionInfo,
    String className,
  ) {
    final methodName = '_save${_toPascalCase(fieldName)}';
    final collectionTableName = '${tableName}_$fieldName';
    final parentFkColumn = '${tableName}_id';

    final buffer = StringBuffer();
    buffer.writeln('  /// Saves the $fieldName collection.');
    buffer.writeln('  Future<void> $methodName(');
    buffer.writeln('    UuidValue aggregateId,');
    buffer.writeln('    dynamic collectionValue,');
    buffer.writeln('  ) async {');
    buffer.writeln('    // Delete existing items');
    buffer.writeln('    await _connection.execute(');
    buffer.writeln(
      '      \'DELETE FROM "$collectionTableName" WHERE "$parentFkColumn" = ?\',',
    );
    buffer.writeln('      [_dialect.encodeUuid(aggregateId)],');
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    // Handle null or empty collections');
    buffer.writeln('    if (collectionValue == null) return;');
    buffer.writeln();

    // Generate save logic based on collection kind
    switch (collectionInfo.kind) {
      case CollectionKind.list:
        buffer.writeln(
          _generateListSaveLogic(
            collectionTableName,
            parentFkColumn,
            collectionInfo,
          ),
        );
      case CollectionKind.set:
        buffer.writeln(
          _generateSetSaveLogic(
            collectionTableName,
            parentFkColumn,
            collectionInfo,
          ),
        );
      case CollectionKind.map:
        buffer.writeln(
          _generateMapSaveLogic(
            collectionTableName,
            parentFkColumn,
            collectionInfo,
          ),
        );
    }

    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Generates save logic for List collections.
  String _generateListSaveLogic(
    String tableName,
    String parentFkColumn,
    CollectionInfo collectionInfo,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('    final items = collectionValue as List;');
    buffer.writeln('    if (items.isEmpty) return;');
    buffer.writeln();
    buffer.writeln('    for (var i = 0; i < items.length; i++) {');
    buffer.writeln('      final item = items[i];');
    buffer.writeln('      final values = <Object?>[');
    buffer.writeln('        _dialect.encodeUuid(aggregateId),');
    buffer.writeln('        i, // position');

    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('        _encodeValue(item),');
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      await _connection.execute(');
        buffer.writeln(
          '        \'INSERT INTO "$tableName" ("$parentFkColumn", "position", "value") VALUES (?, ?, ?)\',',
        );
        buffer.writeln('        values,');
        buffer.writeln('      );');
      case ElementKind.value:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Flatten value object fields');
        buffer.writeln('      if (item is Map<String, dynamic>) {');
        buffer.writeln('        final columns = [');
        buffer.writeln("          '$parentFkColumn',");
        buffer.writeln("          'position',");
        buffer.writeln('        ];');
        buffer.writeln('        for (final key in item.keys) {');
        buffer.writeln('          columns.add(key);');
        buffer.writeln('          values.add(_encodeValue(item[key]));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
      case ElementKind.entity:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Add entity fields');
        buffer.writeln('      if (item is Map<String, dynamic>) {');
        buffer.writeln('        // Flatten nested value objects in the entity');
        buffer.writeln('        final flattened = _flattenForTable(item, []);');
        buffer.writeln('        final columns = [');
        buffer.writeln("          '$parentFkColumn',");
        buffer.writeln("          'position',");
        buffer.writeln('        ];');
        buffer.writeln('        for (final entry in flattened.entries) {');
        buffer.writeln('          columns.add(entry.key);');
        buffer.writeln('          values.add(_encodeValue(entry.value));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
    }

    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates save logic for Set collections.
  String _generateSetSaveLogic(
    String tableName,
    String parentFkColumn,
    CollectionInfo collectionInfo,
  ) {
    final buffer = StringBuffer();
    // Sets are serialized as Lists in JSON, so accept either
    buffer.writeln(
      '    final items = collectionValue is Set ? collectionValue as Set : (collectionValue as List).toSet();',
    );
    buffer.writeln('    if (items.isEmpty) return;');
    buffer.writeln();
    buffer.writeln('    for (final item in items) {');
    buffer.writeln('      final values = <Object?>[');
    buffer.writeln('        _dialect.encodeUuid(aggregateId),');

    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('        _encodeValue(item),');
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      await _connection.execute(');
        buffer.writeln(
          '        \'INSERT INTO "$tableName" ("$parentFkColumn", "value") VALUES (?, ?)\',',
        );
        buffer.writeln('        values,');
        buffer.writeln('      );');
      case ElementKind.value:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Flatten value object fields');
        buffer.writeln('      if (item is Map<String, dynamic>) {');
        buffer.writeln("        final columns = ['$parentFkColumn'];");
        buffer.writeln('        for (final key in item.keys) {');
        buffer.writeln('          columns.add(key);');
        buffer.writeln('          values.add(_encodeValue(item[key]));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
      case ElementKind.entity:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Add entity fields');
        buffer.writeln('      if (item is Map<String, dynamic>) {');
        buffer.writeln('        // Flatten nested value objects in the entity');
        buffer.writeln('        final flattened = _flattenForTable(item, []);');
        buffer.writeln("        final columns = ['$parentFkColumn'];");
        buffer.writeln('        for (final entry in flattened.entries) {');
        buffer.writeln('          columns.add(entry.key);');
        buffer.writeln('          values.add(_encodeValue(entry.value));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
    }

    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates save logic for Map collections.
  String _generateMapSaveLogic(
    String tableName,
    String parentFkColumn,
    CollectionInfo collectionInfo,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('    final map = collectionValue as Map;');
    buffer.writeln('    if (map.isEmpty) return;');
    buffer.writeln();
    buffer.writeln('    for (final entry in map.entries) {');
    buffer.writeln('      final key = entry.key;');
    buffer.writeln('      final value = entry.value;');
    buffer.writeln('      final values = <Object?>[');
    buffer.writeln('        _dialect.encodeUuid(aggregateId),');
    buffer.writeln('        _encodeValue(key), // map_key');

    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('        _encodeValue(value),');
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      await _connection.execute(');
        buffer.writeln(
          '        \'INSERT INTO "$tableName" ("$parentFkColumn", "map_key", "value") VALUES (?, ?, ?)\',',
        );
        buffer.writeln('        values,');
        buffer.writeln('      );');
      case ElementKind.value:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Flatten value object fields');
        buffer.writeln('      if (value is Map<String, dynamic>) {');
        buffer.writeln('        final columns = [');
        buffer.writeln("          '$parentFkColumn',");
        buffer.writeln("          'map_key',");
        buffer.writeln('        ];');
        buffer.writeln('        for (final valueKey in value.keys) {');
        buffer.writeln('          columns.add(valueKey);');
        buffer.writeln('          values.add(_encodeValue(value[valueKey]));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
      case ElementKind.entity:
        buffer.writeln('      ];');
        buffer.writeln();
        buffer.writeln('      // Add entity fields');
        buffer.writeln('      if (value is Map<String, dynamic>) {');
        buffer.writeln('        // Flatten nested value objects in the entity');
        buffer
            .writeln('        final flattened = _flattenForTable(value, []);');
        buffer.writeln('        final columns = [');
        buffer.writeln("          '$parentFkColumn',");
        buffer.writeln("          'map_key',");
        buffer.writeln('        ];');
        buffer.writeln('        for (final valueEntry in flattened.entries) {');
        buffer.writeln('          columns.add(valueEntry.key);');
        buffer.writeln('          values.add(_encodeValue(valueEntry.value));');
        buffer.writeln('        }');
        buffer.writeln();
        buffer.writeln(
          "        final placeholders = List.filled(columns.length, '?').join(', ');",
        );
        buffer.writeln('        await _connection.execute(');
        buffer.writeln(
          '          \'INSERT INTO "$tableName" (\${columns.map((c) => \'"\$c"\').join(\', \')}) VALUES (\$placeholders)\',',
        );
        buffer.writeln('          values,');
        buffer.writeln('        );');
        buffer.writeln('      }');
    }

    buffer.writeln('    }');

    return buffer.toString();
  }

  /// Generates a load method for a specific collection field.
  String _generateCollectionLoadMethod(
    String fieldName,
    String tableName,
    CollectionInfo collectionInfo,
    String className,
  ) {
    final methodName = '_load${_toPascalCase(fieldName)}';
    final collectionTableName = '${tableName}_$fieldName';
    final parentFkColumn = '${tableName}_id';

    final buffer = StringBuffer();
    buffer.writeln('  /// Loads the $fieldName collection.');
    buffer.writeln(
      '  Future<dynamic> $methodName(UuidValue aggregateId) async {',
    );

    // Generate ORDER BY clause for lists
    final orderByClause =
        collectionInfo.kind == CollectionKind.list ? ' ORDER BY position' : '';

    buffer.writeln('    final rows = await _connection.query(');
    buffer.writeln(
      '      \'SELECT * FROM "$collectionTableName" WHERE "$parentFkColumn" = ?$orderByClause\',',
    );
    buffer.writeln('      [_dialect.encodeUuid(aggregateId)],');
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    if (rows.isEmpty) {');

    // Return empty collection - always return List or Map for JSON compatibility
    switch (collectionInfo.kind) {
      case CollectionKind.list:
        buffer.writeln('      return <dynamic>[];');
      case CollectionKind.set:
        // Sets are represented as Lists in JSON
        buffer.writeln('      return <dynamic>[];');
      case CollectionKind.map:
        buffer.writeln('      return <dynamic, dynamic>{};');
    }

    buffer.writeln('    }');
    buffer.writeln();

    // Generate load logic based on collection kind
    switch (collectionInfo.kind) {
      case CollectionKind.list:
        buffer.writeln(
          _generateListLoadLogic(collectionInfo),
        );
      case CollectionKind.set:
        buffer.writeln(
          _generateSetLoadLogic(collectionInfo),
        );
      case CollectionKind.map:
        buffer.writeln(
          _generateMapLoadLogic(collectionInfo),
        );
    }

    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Generates load logic for List collections.
  String _generateListLoadLogic(CollectionInfo collectionInfo) {
    final buffer = StringBuffer();

    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln("      return _decodeValue(row['value'], 'value');");
        buffer.writeln('    }).toList();');
      case ElementKind.value:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln('      // Filter out position and foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln(
          "        if (entry.key != 'position' && !entry.key.endsWith('_id')) {",
        );
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      return _rowToJson(filtered);');
        buffer.writeln('    }).toList();');
      case ElementKind.entity:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln('      // Filter out position and foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln(
          "        if (entry.key != 'position' && !entry.key.endsWith('_id')) {",
        );
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      return _rowToJson(filtered);');
        buffer.writeln('    }).toList();');
    }

    return buffer.toString();
  }

  /// Generates load logic for Set collections.
  String _generateSetLoadLogic(CollectionInfo collectionInfo) {
    final buffer = StringBuffer();

    // Sets are represented as Lists in JSON, so return a List
    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln("      return _decodeValue(row['value'], 'value');");
        buffer.writeln('    }).toList();');
      case ElementKind.value:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln('      // Filter out foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln("        if (!entry.key.endsWith('_id')) {");
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      return _rowToJson(filtered);');
        buffer.writeln('    }).toList();');
      case ElementKind.entity:
        buffer.writeln('    return rows.map((row) {');
        buffer.writeln('      // Filter out foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln("        if (!entry.key.endsWith('_id')) {");
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      return _rowToJson(filtered);');
        buffer.writeln('    }).toList();');
    }

    return buffer.toString();
  }

  /// Generates load logic for Map collections.
  String _generateMapLoadLogic(CollectionInfo collectionInfo) {
    final buffer = StringBuffer();

    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        buffer.writeln('    final map = <dynamic, dynamic>{};');
        buffer.writeln('    for (final row in rows) {');
        buffer.writeln(
          "      final key = _decodeValue(row['map_key'], 'map_key');",
        );
        buffer.writeln(
          "      final value = _decodeValue(row['value'], 'value');",
        );
        buffer.writeln('      map[key] = value;');
        buffer.writeln('    }');
        buffer.writeln('    return map;');
      case ElementKind.value:
        buffer.writeln('    final map = <dynamic, dynamic>{};');
        buffer.writeln('    for (final row in rows) {');
        buffer.writeln(
          "      final key = _decodeValue(row['map_key'], 'map_key');",
        );
        buffer.writeln('      // Filter out map_key and foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln(
          "        if (entry.key != 'map_key' && !entry.key.endsWith('_id')) {",
        );
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      map[key] = _rowToJson(filtered);');
        buffer.writeln('    }');
        buffer.writeln('    return map;');
      case ElementKind.entity:
        buffer.writeln('    final map = <dynamic, dynamic>{};');
        buffer.writeln('    for (final row in rows) {');
        buffer.writeln(
          "      final key = _decodeValue(row['map_key'], 'map_key');",
        );
        buffer.writeln('      // Filter out map_key and foreign key columns');
        buffer.writeln('      final filtered = <String, Object?>{};');
        buffer.writeln('      for (final entry in row.entries) {');
        buffer.writeln(
          "        if (entry.key != 'map_key' && !entry.key.endsWith('_id')) {",
        );
        buffer.writeln('          filtered[entry.key] = entry.value;');
        buffer.writeln('        }');
        buffer.writeln('      }');
        buffer.writeln('      // Reconstruct flattened value objects');
        buffer.writeln('      map[key] = _rowToJson(filtered);');
        buffer.writeln('    }');
        buffer.writeln('    return map;');
    }

    return buffer.toString();
  }

  /// Generates the _flattenForTable helper method.
  String _generateFlattenForTableMethod() {
    return r'''
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
  }''';
  }

  /// Generates the _rowToJson helper method.
  String _generateRowToJsonMethod() {
    return r'''
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
  }''';
  }

  /// Generates a map of field names to their Dart types.
  String _generateFieldTypeMapMethod(TableDefinition rootTable) {
    final buffer = StringBuffer();
    buffer.writeln(
      '  /// Maps field names to their Dart types for type-aware encoding/decoding.',
    );
    buffer.writeln('  static const Map<String, String> _fieldTypes = {');

    for (final column in rootTable.columns) {
      buffer.writeln("    '${column.name}': '${column.dartType}',");
    }

    buffer.writeln('  };');
    return buffer.toString();
  }

  /// Generates the _encodeValue helper method.
  String _generateEncodeValueMethod() {
    return '''
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
  }''';
  }

  /// Generates the _decodeValue helper method.
  String _generateDecodeValueMethod() {
    return '''
  /// Decodes a value from SQL storage.
  dynamic _decodeValue(Object? value, String fieldName) {
    if (value == null) return null;

    // Get the Dart type for this field
    final dartType = _fieldTypes[fieldName];

    // Decode UUIDs (BLOB)
    if (value is List<int> && (dartType == 'UuidValue' || fieldName == 'id' || fieldName.endsWith('Id'))) {
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
  }''';
  }

  /// Finds the JSON key for an entity table.
  ///
  /// Uses the mapping built during table analysis to find the actual
  /// field name in the aggregate root class.
  String _findJsonKeyForTable(TableDefinition table) {
    // Look up the field name from our mapping
    final fieldName = _entityToFieldName[table.className];
    if (fieldName != null) {
      return fieldName;
    }

    // Fallback: convert class name to camelCase and pluralize
    // e.g., "OrderItem" -> "orderItems"
    final className = table.className;
    final camelCase = className[0].toLowerCase() + className.substring(1);
    return '${camelCase}s';
  }

  /// Finds the parent foreign key column name in an entity table.
  String? _findParentForeignKeyColumn(TableDefinition table) {
    // Look for a foreign key that references the parent with CASCADE
    for (final fk in table.foreignKeys) {
      if (fk.onDelete == CascadeAction.cascade) {
        return fk.columnName;
      }
    }
    // Return null if no parent FK found (e.g., for collection entities)
    return null;
  }

  /// Converts snake_case to PascalCase.
  String _toPascalCase(String snakeCase) {
    return snakeCase
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join();
  }

  /// Generates a method signature from a MethodElement.
  String _generateMethodSignature(MethodElement method) {
    final returnType =
        method.returnType.getDisplayString(withNullability: true);
    final params = method.parameters.map((p) {
      final type = p.type.getDisplayString(withNullability: true);
      return '$type ${p.name}';
    }).join(', ');

    return '$returnType ${method.name}($params)';
  }
}
