/// Code generator for MySQL repository implementations.
library;

// ignore_for_file: deprecated_member_use, avoid_redundant_argument_values

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_mysql/src/annotations/generate_mysql_repository.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function for the MySQL repository generator.
///
/// This function is referenced in build.yaml and creates the builder
/// that generates MySQL repository implementations.
///
/// The builder uses [SharedPartBuilder] to generate `.mysql_repository.g.part`
/// files for classes annotated with [@GenerateMysqlRepository].
Builder mysqlRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [MysqlRepositoryGenerator()],
    'mysql_repository',
  );
}

/// Generator for MySQL repository implementations.
///
/// This generator processes classes annotated with [GenerateMysqlRepository]
/// and generates MySQL repository implementations with full normalization,
/// multi-table persistence, and value object embedding.
class MysqlRepositoryGenerator
    extends GeneratorForAnnotation<GenerateMysqlRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateMysqlRepository.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateMysqlRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateMysqlRepository.',
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

    const analyzer = RelationshipAnalyzer();
    const typeMapper = TypeMapper();

    // Discover all types in dependency order
    final discoveredTypes = analyzer.analyzeAggregate(aggregateRoot);

    // Generate table definitions for each type
    final tables = <String, TableDefinition>{};

    for (final classElement in discoveredTypes) {
      // Skip value objects - they are embedded, not stored in separate tables
      if (analyzer.isValueObject(classElement)) {
        continue;
      }

      // Use the provided table name for the aggregate root, snake_case for others
      final tableName = classElement == aggregateRoot
          ? aggregateTableName
          : _toSnakeCase(classElement.name);

      final tableDef = _generateTableDefinition(
        classElement,
        analyzer,
        typeMapper,
        tableName,
      );
      tables[classElement.name] = tableDef;
    }

    // Add parent foreign keys to entity tables
    _addParentForeignKeys(tables, aggregateRoot, aggregateTableName, analyzer);

    return tables;
  }

  /// Maps entity class names to their JSON field names in the aggregate.
  final _entityToFieldName = <String, String>{};

  /// Adds parent foreign key columns to entity tables.
  ///
  /// For each entity that's part of a List field in the aggregate,
  /// adds a foreign key column back to the parent aggregate.
  void _addParentForeignKeys(
    Map<String, TableDefinition> tables,
    ClassElement aggregateRoot,
    String aggregateTableName,
    RelationshipAnalyzer analyzer,
  ) {
    // Find all List<Entity> fields in the aggregate
    for (final field in aggregateRoot.fields) {
      if (field.type.isDartCoreList) {
        final elementType = (field.type as InterfaceType).typeArguments.first;
        if (elementType is InterfaceType) {
          final entityClass = elementType.element;
          if (entityClass is ClassElement &&
              !analyzer.isValueObject(entityClass)) {
            // Store the mapping from entity class to field name
            _entityToFieldName[entityClass.name] = field.name;

            // This is an entity in a list - add parent FK
            final entityTable = tables[entityClass.name];
            if (entityTable != null) {
              // Add foreign key column
              final fkColumnName =
                  '${aggregateTableName.replaceAll('_', '')}_id';
              final fkColumn = ColumnDefinition(
                name: fkColumnName,
                sqlType: 'BINARY(16)',
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
      if (referencedClass != null && analyzer.isValueObject(referencedClass)) {
        // Special case: UuidValue should be stored as BINARY(16), not embedded
        if (referencedClass.name == 'UuidValue') {
          final column = ColumnDefinition(
            name: fieldName,
            sqlType: 'BINARY(16)',
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
          fieldType.nullabilitySuffix.toString().contains('question'),
        );
        columns.addAll(embeddedColumns);
        continue;
      }

      // Check if it's an entity or aggregate reference
      if (referencedClass != null &&
          (analyzer.isEntity(referencedClass) ||
              analyzer.isAggregateRoot(referencedClass))) {
        // Add foreign key column
        final fkColumn = ColumnDefinition(
          name: '${fieldName}_id',
          sqlType: 'BINARY(16)',
          dartType: 'UuidValue',
          isNullable:
              fieldType.nullabilitySuffix.toString().contains('question'),
          isPrimaryKey: false,
          isForeignKey: true,
        );
        columns.add(fkColumn);

        // Add foreign key constraint
        final cascadeAction = analyzer.isAggregateRoot(referencedClass)
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
      var sqlType = typeMapper.getSqlType(dartTypeName);

      // MySQL-specific: DateTime needs BIGINT for milliseconds since epoch
      if (dartTypeName == 'DateTime' && sqlType == 'INTEGER') {
        sqlType = 'BIGINT';
      }

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
          sqlType: 'BINARY(16)',
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
      isAggregateRoot: analyzer.isAggregateRoot(classElement),
    );
  }

  /// Generates embedded columns for a value object.
  ///
  /// Value objects are flattened into the parent table with prefixed column names.
  List<ColumnDefinition> _generateEmbeddedColumns(
    String prefix,
    ClassElement valueObjectClass,
    TypeMapper typeMapper,
    bool isNullable,
  ) {
    final columns = <ColumnDefinition>[];

    for (final field in valueObjectClass.fields) {
      if (field.isStatic) continue;

      final fieldType = field.type;
      final dartTypeName = fieldType.getDisplayString(withNullability: false);
      var sqlType = typeMapper.getSqlType(dartTypeName);

      // MySQL-specific: DateTime needs BIGINT for milliseconds since epoch
      if (dartTypeName == 'DateTime' && sqlType == 'INTEGER') {
        sqlType = 'BIGINT';
      }

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
      '/// Generated MySQL repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class provides CRUD operations with full normalization,',
    );
    buffer.writeln('/// multi-table persistence, and value object embedding.');
    buffer.writeln('class ${className}MysqlRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - An open MySQL database connection.');
    buffer.writeln('  ${className}MysqlRepository(this._connection);');
    buffer.writeln();

    // Fields and getters
    buffer.writeln('  /// The MySQL database connection.');
    buffer.writeln('  final MysqlConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for MySQL.');
    buffer.writeln('  final _dialect = MysqlDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables));
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
    buffer.writeln(_generateMapMysqlExceptionMethod());

    buffer.writeln('}');

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
      '/// Generated abstract base MySQL repository for [$className] aggregate.',
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
      'abstract class ${className}MysqlRepositoryBase implements ${implements.element.name} {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - An open MySQL database connection.');
    buffer.writeln('  ${className}MysqlRepositoryBase(this._connection);');
    buffer.writeln();

    // Protected fields for subclass access
    buffer.writeln('  /// The MySQL database connection (protected).');
    buffer.writeln('  final MysqlConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for MySQL (protected).');
    buffer.writeln('  final _dialect = MysqlDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer (protected).');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables));
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
    buffer.writeln(_generateMapMysqlExceptionMethod());
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

  /// Generates the createTables method.
  String _generateCreateTablesMethod(Map<String, TableDefinition> tables) {
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
    // Create aggregate root table first, then entity tables
    final aggregateTable = tables.values.firstWhere((t) => t.isAggregateRoot);
    final entityTables = tables.values.where((t) => !t.isAggregateRoot);

    // Create aggregate root table first
    buffer.writeln('      // Create table: ${aggregateTable.tableName}');
    buffer.writeln('      await _connection.execute(');
    buffer.writeln("        '''");
    buffer.writeln(_generateCreateTableSql(aggregateTable));
    buffer.writeln("        ''',");
    buffer.writeln('      );');
    buffer.writeln();

    // Then create entity tables
    for (final table in entityTables) {
      buffer.writeln('      // Create table: ${table.tableName}');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln("        '''");
      buffer.writeln(_generateCreateTableSql(table));
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
    buffer.writeln('CREATE TABLE IF NOT EXISTS ${table.tableName} (');

    // Add columns
    final columnDefs = <String>[];
    for (final column in table.columns) {
      final parts = <String>[
        column.name,
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
          '  FOREIGN KEY (${fk.columnName}) '
          'REFERENCES ${fk.referencedTable}(${fk.referencedColumn}) '
          'ON DELETE $onDelete',
        );
      }
      buffer.write(fkDefs.join(',\n'));
    }

    buffer.write('\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

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

    // Build SELECT with BIN_TO_UUID for UUID columns
    final aggregateTable = tables.values.firstWhere((t) => t.isAggregateRoot);
    final selectColumns = <String>[];
    for (final column in aggregateTable.columns) {
      if (column.sqlType == 'BINARY(16)') {
        selectColumns.add('BIN_TO_UUID(`${column.name}`) as `${column.name}`');
      } else {
        selectColumns.add('`${column.name}`');
      }
    }
    final selectClause = selectColumns.join(', ');

    buffer.writeln('        final rows = await _connection.query(');
    buffer.writeln(
      "          'SELECT $selectClause FROM $tableName WHERE id = ?',",
    );
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
    final entityTables =
        tables.values.where((t) => t.tableName != tableName).toList();

    if (entityTables.isNotEmpty) {
      buffer.writeln('        // Load nested entities');
      for (final entityTable in entityTables) {
        buffer.writeln(
          "        json['${_findJsonKeyForTable(entityTable)}'] = await _load${_toPascalCase(entityTable.tableName)}(id);",
        );
      }
      buffer.writeln();
    }

    buffer.writeln('        return _serializer.fromJson(json);');
    buffer.writeln('      } on RepositoryException {');
    buffer.writeln('        rethrow;');
    buffer.writeln('      } catch (e) {');
    buffer.writeln("        throw _mapMysqlException(e, 'getById');");
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
    final entityTables =
        tables.values.where((t) => t.tableName != tableName).toList();

    buffer.writeln(
      '        // Save aggregate root first (required for foreign key constraints)',
    );
    buffer.writeln(
      '        final rootData = _flattenForTable(json, [${entityTables.map((t) => "'${_findJsonKeyForTable(t)}'").join(', ')}]);',
    );
    buffer.writeln('        final columns = rootData.keys.toList();');
    buffer.writeln(
      '        final values = columns.map((k) => _encodeValue(rootData[k])).toList();',
    );
    buffer.writeln();
    buffer.writeln(
      "        final placeholders = List.filled(columns.length, '?').join(', ');",
    );
    buffer.writeln('        final updateClauses = columns.map((c) => ');
    buffer.writeln(r"            '$c = VALUES($c)').join(', ');");
    buffer.writeln('        await _connection.execute(');
    buffer.writeln(
      "          'INSERT INTO $tableName (\${columns.join(', ')}) VALUES (\$placeholders) '",
    );
    buffer.writeln(r"          'ON DUPLICATE KEY UPDATE $updateClauses',");
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
    buffer.writeln('      } catch (e) {');
    buffer.writeln("        throw _mapMysqlException(e, 'save');");
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
          'SELECT id FROM $tableName WHERE id = ?',
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
          'DELETE FROM $tableName WHERE id = ?',
          [_dialect.encodeUuid(id)],
        );
      } on RepositoryException {
        rethrow;
      } catch (e) {
        throw _mapMysqlException(e, 'deleteById');
      }
    });
  }''';
  }

  /// Generates the MySQL exception mapping helper method.
  String _generateMapMysqlExceptionMethod() {
    return r'''
  /// Maps MySQL exceptions to RepositoryException types.
  RepositoryException _mapMysqlException(
    Object error,
    String operation,
  ) {
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
  }''';
  }

  /// Generates helper methods for multi-table persistence.
  String _generateHelperMethods(
    Map<String, TableDefinition> tables,
    String rootTableName,
    String className,
  ) {
    final buffer = StringBuffer();

    // Generate helper methods for each entity table
    final entityTables =
        tables.values.where((t) => t.tableName != rootTableName).toList();

    for (final entityTable in entityTables) {
      buffer.writeln(_generateSaveEntityMethod(entityTable));
      buffer.writeln();
      buffer.writeln(_generateLoadEntityMethod(entityTable));
      buffer.writeln();
    }

    // Generate utility methods (always generate for consistency)
    buffer.writeln(_generateFlattenForTableMethod());
    buffer.writeln();
    buffer.writeln(_generateRowToJsonMethod());
    buffer.writeln();
    buffer.writeln(_generateEncodeValueMethod());
    buffer.writeln();
    buffer.writeln(_generateDecodeValueMethod());

    return buffer.toString();
  }

  /// Generates a save method for an entity table.
  String _generateSaveEntityMethod(TableDefinition table) {
    final methodName = '_save${_toPascalCase(table.tableName)}';
    final jsonKey = _findJsonKeyForTable(table);

    return '''
  /// Saves ${table.tableName} entities.
  Future<void> $methodName(dynamic aggregate, Map<String, dynamic> json) async {
    // Delete existing entities for this aggregate
    await _connection.execute(
      'DELETE FROM ${table.tableName} WHERE ${_findParentForeignKeyColumn(table)} = ?',
      [_dialect.encodeUuid(aggregate.id)],
    );

    // Get entities from JSON
    final entitiesJson = json['$jsonKey'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity
    for (final entityJson in entitiesJson) {
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['${_findParentForeignKeyColumn(table)}'] = aggregate.id.toString();

      // Generate synthetic ID for entity if not present
      if (!entityJson.containsKey('id')) {
        entityJson['id'] = UuidValue.generate().toString();
      }

      // Flatten and save
      final flattened = _flattenForTable(entityJson, []);
      final columns = flattened.keys.toList();
      final values = columns.map((k) => _encodeValue(flattened[k])).toList();

      final placeholders = List.filled(columns.length, '?').join(', ');
      final updateClauses = columns.map((c) => 
          '\$c = VALUES(\$c)').join(', ');
      await _connection.execute(
        'INSERT INTO ${table.tableName} (\${columns.join(', ')}) VALUES (\$placeholders) '
        'ON DUPLICATE KEY UPDATE \$updateClauses',
        values,
      );
    }
  }''';
  }

  /// Generates a load method for an entity table.
  String _generateLoadEntityMethod(TableDefinition table) {
    final methodName = '_load${_toPascalCase(table.tableName)}';
    final parentFkColumn = _findParentForeignKeyColumn(table);

    // Build SELECT with BIN_TO_UUID for UUID columns
    final selectColumns = <String>[];
    for (final column in table.columns) {
      if (column.sqlType == 'BINARY(16)') {
        selectColumns.add('BIN_TO_UUID(`${column.name}`) as `${column.name}`');
      } else {
        selectColumns.add('`${column.name}`');
      }
    }
    final selectClause = selectColumns.join(', ');

    return '''
  /// Loads ${table.tableName} entities for an aggregate.
  Future<List<Map<String, dynamic>>> $methodName(UuidValue aggregateId) async {
    final rows = await _connection.query(
      'SELECT $selectClause FROM ${table.tableName} WHERE $parentFkColumn = ? ORDER BY createdAt',
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

    // UUIDs are returned as strings from BIN_TO_UUID()
    // No special decoding needed for UUID fields
    
    // Decode DateTimes (stored as BIGINT milliseconds since epoch)
    if (fieldName.endsWith('At') && value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    
    // Decode Blob types (for TEXT fields that might be returned as Blob)
    if (value is Blob) {
      final bytes = value.toBytes();
      return String.fromCharCodes(bytes);
    }

    // Decode DateTimes (TIMESTAMP)
    if (value is DateTime || (value is String && fieldName.endsWith('At'))) {
      try {
        if (value is DateTime) {
          return value.toIso8601String();
        }
        final dateTime = DateTime.tryParse(value as String);
        if (dateTime != null) {
          return dateTime.toIso8601String();
        }
      } catch (_) {
        return value;
      }
    }

    // Decode booleans (TINYINT(1))
    // Common boolean field name patterns
    if (value is int && 
        (fieldName.startsWith('is') || 
         fieldName.startsWith('has') || 
         fieldName.startsWith('can') ||
         fieldName.startsWith('should') ||
         fieldName.endsWith('Enabled') ||
         fieldName.endsWith('Active') ||
         fieldName.endsWith('Valid'))) {
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
  String _findParentForeignKeyColumn(TableDefinition table) {
    // Look for a foreign key that references the parent with CASCADE
    for (final fk in table.foreignKeys) {
      if (fk.onDelete == CascadeAction.cascade) {
        return fk.columnName;
      }
    }
    // Fallback: this shouldn't happen if tables are generated correctly
    throw StateError(
      'No parent foreign key found in entity table ${table.tableName}',
    );
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
