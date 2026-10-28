/// Code generator for MySQL repository implementations.
library;

// ignore_for_file: deprecated_member_use, avoid_redundant_argument_values

import 'package:analyzer/dart/element/element.dart' hide ElementKind;
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart/dddart.dart' show Identity;
import 'package:dddart_repository_mysql/src/annotations/generate_mysql_repository.dart';
import 'package:dddart_repository_mysql/src/dialect/mysql_dialect.dart';
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
  String _rootIdentityType = 'UuidValue';
  String _rootClassName = '';
  final _identityTypes = <String>{};
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
    _identityTypes.clear();
    _rootClassName = className;

    // Validate class extends UuidAggregateRoot
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
    _rootIdentityType =
        _identityName(IdentityTypeAnalysis.identityOf(classElement));
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

  /// Validates that a class extends UuidAggregateRoot.
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
      final value = annotation.computeConstantValue();
      if (value == null) return false;
      final typeName = value.type?.element?.name;
      return typeName == 'Serializable';
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
    final methods = <String, MethodElement>{};

    // Get methods from the interface itself
    for (final method in interfaceType.methods) {
      methods.putIfAbsent(method.name, () => method);
    }

    // Get methods from all superinterfaces (including Repository<T, UuidValue>)
    for (final supertype in interfaceType.allSupertypes) {
      final supertypeName = supertype.element.name;
      // Skip Object and system classes
      if (supertypeName == 'Object' ||
          supertypeName.startsWith('_') ||
          supertype.element.library.name.startsWith('dart.')) {
        continue;
      }
      for (final method in supertype.methods) {
        methods.putIfAbsent(method.name, () => method);
      }
    }

    return methods.values.toList();
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
    const dialect = MysqlDialect();

    // Discover all types in dependency order
    final discoveredTypes = _analyzer.analyzeAggregate(aggregateRoot);

    // Discover collection fields in the aggregate root
    for (final field in _getAllFields(aggregateRoot)) {
      if (field.isStatic || field.isSynthetic) continue;

      // Validate collection types before analyzing
      try {
        collectionAnalyzer.validateCollectionType(
          IdentityTypeAnalysis.fieldType(aggregateRoot, field),
        );
      } catch (e) {
        if (e is UnsupportedError) {
          throw InvalidGenerationSourceError(
            'Unsupported collection type in field "${field.name}":\n${e.message}',
            element: field,
          );
        }
        rethrow;
      }

      final collectionInfo = collectionAnalyzer.analyzeCollection(
        field,
        resolvedType: IdentityTypeAnalysis.fieldType(aggregateRoot, field),
      );
      if (collectionInfo != null) {
        if (collectionInfo.elementKind == ElementKind.entity &&
            collectionInfo.kind != CollectionKind.list) {
          throw InvalidGenerationSourceError(
            'MySQL entity collections currently require List<Entity>; '
            'Set/Map entity collections are not supported by this generator.',
            element: field,
          );
        }
        // Skip entity collections - they're handled by the relationship analyzer
        if (collectionInfo.elementKind != ElementKind.entity) {
          _collectionFields[field.name] = collectionInfo;
        }
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
  /// For each entity that's part of a List field in the aggregate,
  /// adds a foreign key column back to the parent aggregate.
  /// Also adds a position column to preserve List order.
  void _addParentForeignKeys(
    Map<String, TableDefinition> tables,
    ClassElement aggregateRoot,
    String aggregateTableName,
    RelationshipAnalyzer analyzer,
  ) {
    // Find all List<Entity> fields in the aggregate
    for (final field in _getAllFields(aggregateRoot)) {
      if (field.type.isDartCoreList) {
        final elementType = (field.type as InterfaceType).typeArguments.first;
        if (elementType is InterfaceType) {
          final entityClass = elementType.element;
          if (entityClass is ClassElement &&
              !_analyzer.isValueObject(entityClass)) {
            // Store the mapping from entity class to field name
            _entityToFieldName[entityClass.name] = field.name;

            // This is an entity in a list - add parent FK and position column
            final entityTable = tables[entityClass.name];
            if (entityTable != null) {
              // Add foreign key column
              final fkColumnName =
                  '${aggregateTableName.replaceAll('_', '')}_id';
              final fkColumn = ColumnDefinition(
                name: fkColumnName,
                sqlType: const MysqlDialect().identityColumnType,
                dartType: _rootIdentityType,
                isNullable: false,
                isPrimaryKey: false,
                isForeignKey: true,
                jsonPath: [fkColumnName],
              );

              // Add position column to preserve List order
              const positionColumn = ColumnDefinition(
                name: '_list_position',
                sqlType: 'INTEGER',
                dartType: 'int',
                isNullable: false,
                isPrimaryKey: false,
                isForeignKey: false,
              );

              // Add foreign key constraint
              final fk = ForeignKeyDefinition(
                columnName: fkColumnName,
                referencedTable: aggregateTableName,
                referencedColumn: 'id',
                onDelete: CascadeAction.cascade,
              );

              // Create new table definition with added columns and FK
              final updatedTable = TableDefinition(
                tableName: entityTable.tableName,
                className: entityTable.className,
                columns: [...entityTable.columns, fkColumn, positionColumn],
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
  List<FieldElement> _getAllFields(ClassElement classElement) =>
      IdentityTypeAnalysis.instanceFields(classElement);

  /// Records concrete identity kinds for generated typed codec dispatch.
  String _identityName(DartType type) {
    if (type is! InterfaceType ||
        const TypeChecker.fromRuntime(Identity).isExactly(type.element)) {
      throw InvalidGenerationSourceError(
        'SQL identity fields require a concrete identity type.',
      );
    }
    final name = type.getDisplayString(withNullability: false);
    _identityTypes.add(name);
    return name;
  }

  /// Generates exact identity columns before considering embedded values.
  TableDefinition _generateTableDefinition(
    ClassElement classElement,
    RelationshipAnalyzer analyzer,
    TypeMapper typeMapper,
    SqlDialect dialect,
    String tableName,
  ) {
    final identity =
        _identityName(IdentityTypeAnalysis.identityOf(classElement));
    final columns = <ColumnDefinition>[
      ColumnDefinition(
        name: 'id',
        sqlType: dialect.identityColumnType,
        dartType: identity,
        isNullable: false,
        isPrimaryKey: true,
        isForeignKey: false,
        jsonPath: const ['id'],
      ),
    ];
    final foreignKeys = <ForeignKeyDefinition>[];
    for (final field in _getAllFields(classElement)) {
      if (field.isStatic || field.isSynthetic || field.name == 'id') continue;
      final type = IdentityTypeAnalysis.fieldType(classElement, field);
      if (type.isDartCoreList || type.isDartCoreSet || type.isDartCoreMap) {
        continue;
      }
      final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
      if (IdentityTypeAnalysis.isIdentity(type)) {
        columns.add(
          ColumnDefinition(
            name: field.name,
            sqlType: dialect.identityColumnType,
            dartType: _identityName(type),
            isNullable: nullable,
            isPrimaryKey: false,
            isForeignKey: false,
            jsonPath: [field.name],
          ),
        );
        continue;
      }
      final referenced = _getReferencedClass(type);
      if (referenced != null && analyzer.isValueObject(referenced)) {
        columns.addAll(
          _generateEmbeddedColumns(
            field.name,
            referenced,
            typeMapper,
            dialect,
            nullable,
          ),
        );
        continue;
      }
      if (referenced != null && analyzer.isEntity(referenced)) {
        final targetId =
            _identityName(IdentityTypeAnalysis.identityOf(referenced));
        columns.add(
          ColumnDefinition(
            name: '${field.name}_id',
            sqlType: dialect.identityColumnType,
            dartType: targetId,
            isNullable: nullable,
            isPrimaryKey: false,
            isForeignKey: true,
            jsonPath: [field.name, 'id'],
          ),
        );
        foreignKeys.add(
          ForeignKeyDefinition(
            columnName: '${field.name}_id',
            referencedTable: _toSnakeCase(referenced.name),
            referencedColumn: 'id',
            onDelete: analyzer.isAggregateRoot(referenced)
                ? CascadeAction.restrict
                : CascadeAction.cascade,
          ),
        );
        continue;
      }
      final sqlType = typeMapper.getSqlTypeFor(type, dialect);
      if (sqlType != null) {
        columns.add(
          ColumnDefinition(
            name: field.name,
            sqlType: sqlType,
            dartType: type.getDisplayString(withNullability: false),
            isNullable: nullable,
            isPrimaryKey: false,
            isForeignKey: false,
            jsonPath: [field.name],
          ),
        );
      }
    }
    return TableDefinition(
      tableName: tableName,
      className: classElement.name,
      columns: columns,
      foreignKeys: foreignKeys,
      isAggregateRoot: analyzer.isAggregateRoot(classElement),
    );
  }

  List<ColumnDefinition> _generateEmbeddedColumns(
    String prefix,
    ClassElement valueObjectClass,
    TypeMapper typeMapper,
    SqlDialect dialect,
    bool isNullable, [
    List<String>? pathPrefix,
  ]) {
    final columns = <ColumnDefinition>[];
    for (final field in _getAllFields(valueObjectClass)) {
      if (field.isStatic || field.isSynthetic) continue;
      final type = IdentityTypeAnalysis.fieldType(valueObjectClass, field);
      final name = prefix.isEmpty ? field.name : '${prefix}_${field.name}';
      final path = [
        ...(pathPrefix ?? (prefix.isEmpty ? <String>[] : [prefix])),
        field.name,
      ];
      final nullable =
          isNullable || type.nullabilitySuffix == NullabilitySuffix.question;
      final sqlType = typeMapper.getSqlTypeFor(type, dialect);
      if (sqlType != null) {
        final typeName = IdentityTypeAnalysis.isIdentity(type)
            ? _identityName(type)
            : type.getDisplayString(withNullability: false);
        columns.add(
          ColumnDefinition(
            name: name,
            sqlType: sqlType,
            dartType: typeName,
            isNullable: nullable,
            isPrimaryKey: false,
            isForeignKey: false,
            jsonPath: path,
          ),
        );
      } else {
        final referenced = _getReferencedClass(type);
        if (referenced != null && _analyzer.isValueObject(referenced)) {
          columns.addAll(
            _generateEmbeddedColumns(
              name,
              referenced,
              typeMapper,
              dialect,
              nullable,
              path,
            ),
          );
        }
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
        : 'implements Repository<$className, $_rootIdentityType>';

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
    buffer.writeln(
      '  ${className}MysqlRepository(this._connection, {IdentityCodecRegistry? identityCodecs}) : _identityCodecs = identityCodecs ?? IdentityCodecRegistry();',
    );
    buffer.writeln();

    // Fields and getters
    buffer.writeln('  /// The MySQL database connection.');
    buffer.writeln('  final MysqlConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for MySQL.');
    buffer.writeln('  final _dialect = MysqlDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final IdentityCodecRegistry _identityCodecs;');
    buffer.writeln(
      '  late final _serializer = ${className}JsonSerializer.withIdentityCodecs(_identityCodecs, const SerializationConfig(includeNullFields: true));',
    );
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables, className));
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
    buffer.writeln(
      '  ${className}MysqlRepositoryBase(this._connection, {IdentityCodecRegistry? identityCodecs}) : _identityCodecs = identityCodecs ?? IdentityCodecRegistry();',
    );
    buffer.writeln();

    // Protected fields for subclass access
    buffer.writeln('  /// The MySQL database connection (library-private).');
    buffer.writeln('  final MysqlConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The SQL dialect for MySQL (library-private).');
    buffer.writeln('  final _dialect = MysqlDialect();');
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer (library-private).');
    buffer.writeln('  final IdentityCodecRegistry _identityCodecs;');
    buffer.writeln(
      '  late final _serializer = ${className}JsonSerializer.withIdentityCodecs(_identityCodecs, const SerializationConfig(includeNullFields: true));',
    );
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Generate createTables method
    buffer.writeln(_generateCreateTablesMethod(tables, className));
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
  String _generateCreateTablesMethod(
    Map<String, TableDefinition> tables,
    String className,
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

    // Generate CREATE TABLE statements for collection junction tables
    for (final entry in _collectionFields.entries) {
      final fieldName = entry.key;
      final collectionInfo = entry.value;
      final junctionTableName =
          '${aggregateTable.tableName}_${fieldName}_items';

      buffer
          .writeln('      // Create junction table for collection: $fieldName');
      buffer.writeln('      await _connection.execute(');
      buffer.writeln("        '''");
      buffer.writeln(
        _generateCollectionTableSql(
          junctionTableName,
          aggregateTable.tableName,
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

  /// Generates a junction schema with the same identity representation as its parent.
  String _generateCollectionTableSql(
    String tableName,
    String parentTableName,
    CollectionInfo collectionInfo,
    RelationshipAnalyzer analyzer,
  ) {
    const dialect = MysqlDialect();
    const mapper = TypeMapper();
    const q = '`';
    final parent = '${parentTableName}_id';
    final columns = <String>[
      '  $q$parent$q ${dialect.identityColumnType} NOT NULL',
    ];
    if (collectionInfo.kind == CollectionKind.list) {
      columns.add('  ${q}position$q ${dialect.integerColumnType} NOT NULL');
    }
    if (collectionInfo.kind == CollectionKind.map) {
      final key = collectionInfo.keyType!;
      if (IdentityTypeAnalysis.isIdentity(key)) _identityName(key);
      final sqlType =
          mapper.getSqlTypeFor(key, dialect) ?? dialect.textColumnType;
      columns.add('  ${q}map_key$q $sqlType NOT NULL');
    }
    switch (collectionInfo.elementKind) {
      case ElementKind.primitive:
        final type = collectionInfo.elementType;
        if (IdentityTypeAnalysis.isIdentity(type)) _identityName(type);
        final sqlType =
            mapper.getSqlTypeFor(type, dialect) ?? dialect.textColumnType;
        final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
        columns.add('  ${q}value$q $sqlType${nullable ? '' : ' NOT NULL'}');
      case ElementKind.value:
      case ElementKind.entity:
        final element = (collectionInfo.elementType as InterfaceType).element
            as ClassElement;
        final fields = collectionInfo.elementKind == ElementKind.entity
            ? _generateTableDefinition(
                element,
                analyzer,
                mapper,
                dialect,
                tableName,
              ).columns
            : _generateEmbeddedColumns('', element, mapper, dialect, false);
        for (final field in fields) {
          columns.add(
            '  $q${field.name}$q ${field.sqlType}${field.isPrimaryKey ? ' PRIMARY KEY' : ''}${field.isNullable ? '' : ' NOT NULL'}',
          );
        }
    }
    columns.add(
      '  FOREIGN KEY ($q$parent$q) REFERENCES $q$parentTableName$q(${q}id$q) ON DELETE CASCADE',
    );
    if (collectionInfo.kind == CollectionKind.list) {
      columns.add('  UNIQUE ($q$parent$q, ${q}position$q)');
    } else if (collectionInfo.kind == CollectionKind.set &&
        collectionInfo.elementKind == ElementKind.primitive) {
      columns.add('  UNIQUE ($q$parent$q, ${q}value$q)');
    } else if (collectionInfo.kind == CollectionKind.map) {
      columns.add('  UNIQUE ($q$parent$q, ${q}map_key$q)');
    }
    return 'CREATE TABLE IF NOT EXISTS $q$tableName$q (\n${columns.join(',\n')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4';
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
          'REFERENCES `${fk.referencedTable}`(${fk.referencedColumn}) '
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
    buffer
        .writeln('  Future<$className> getById($_rootIdentityType id) async {');
    buffer.writeln('    _encodeIdentity(id);');
    buffer.writeln('    await _validateIdentitySchema();');
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
    buffer.writeln('          [_encodeIdentity(id)],');
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
    final entityTables = tables.values
        .where(
          (t) =>
              t.tableName != tableName &&
              _findParentForeignKeyColumn(t) != null,
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
    buffer.writeln('    _encodeIdentity(aggregate.id);');
    buffer.writeln('    await _validateIdentitySchema();');
    buffer.writeln('    await _connection.transaction(() async {');
    buffer.writeln('      try {');
    buffer.writeln('        // Serialize aggregate to JSON');
    buffer.writeln('        final json = _serializer.toJson(aggregate);');
    buffer.writeln();

    // Generate save logic for aggregate root FIRST
    final entityTables = tables.values
        .where(
          (t) =>
              t.tableName != tableName &&
              _findParentForeignKeyColumn(t) != null,
        )
        .toList();

    // Build exclude keys list (entity fields + collection fields)
    final excludeKeys = <String>[];
    for (final entityTable in entityTables) {
      excludeKeys.add("'${_findJsonKeyForTable(entityTable)}'");
    }
    for (final fieldName in _collectionFields.keys) {
      excludeKeys.add("'$fieldName'");
    }

    buffer.writeln(
      '        // Save aggregate root first (required for foreign key constraints)',
    );
    buffer.writeln(
      '        final rootData = _flattenForTable(json, [${excludeKeys.join(', ')}]);',
    );
    buffer.writeln('        final columns = rootData.keys.toList();');
    buffer.writeln(
      '        final values = columns.map((k) => _encodeValue(rootData[k], _fieldTypes[k])).toList();',
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
  Future<void> deleteById($_rootIdentityType id) async {
    _encodeIdentity(id);
    await _validateIdentitySchema();
    await _connection.transaction(() async {
      try {
        // Check if aggregate exists
        final rows = await _connection.query(
          'SELECT id FROM $tableName WHERE id = ?',
          [_encodeIdentity(id)],
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
          [_encodeIdentity(id)],
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
    if (error is RepositoryException) return error;
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

    // Get the root table by className (tables are keyed by class name)
    final rootTable = tables[className];
    if (rootTable == null) {
      throw StateError('Root table for $className not found in tables map');
    }

    // Generate helper methods for each entity table
    final entityTables = tables.values
        .where(
          (t) =>
              t.tableName != rootTableName &&
              _findParentForeignKeyColumn(t) != null,
        )
        .toList();

    for (final entityTable in entityTables) {
      buffer.writeln(_generateSaveEntityMethod(entityTable));
      buffer.writeln();
      buffer.writeln(_generateLoadEntityMethod(entityTable));
      buffer.writeln();
    }

    // Generate collection save and load methods
    buffer.writeln(_generateCollectionSaveMethods(className, rootTableName));
    buffer.writeln(_generateCollectionLoadMethods(className, rootTableName));

    // Generate utility methods (always generate for consistency)
    buffer.writeln(_generateFlattenForTableMethod());
    buffer.writeln();
    buffer.writeln(_generateRowToJsonMethod());
    buffer.writeln();
    buffer.writeln(_generateFieldTypeMapMethod(rootTable, tables));
    buffer.writeln();
    buffer.writeln(_generateIdentitySchemaValidator(tables, rootTable));
    buffer.writeln();
    buffer.writeln(_generateEncodeValueMethod());
    buffer.writeln();
    buffer.writeln(_generateDecodeValueMethod());

    return buffer.toString();
  }

  /// Generates a save method for an entity table.
  String _generateIdentitySchemaValidator(
    Map<String, TableDefinition> tables,
    TableDefinition rootTable,
  ) {
    final columns = <String, Set<String>>{};
    for (final table in tables.values) {
      columns[table.tableName] = {
        for (final column in table.columns)
          if (_identityTypes.contains(column.dartType)) column.name,
      };
    }
    for (final entry in _collectionFields.entries) {
      final info = entry.value;
      final names = <String>{'${rootTable.tableName}_id'};
      if (info.keyType != null &&
          IdentityTypeAnalysis.isIdentity(info.keyType!)) {
        names.add('map_key');
      }
      if (info.elementKind == ElementKind.primitive &&
          IdentityTypeAnalysis.isIdentity(info.elementType)) {
        names.add('value');
      }
      if (info.elementKind == ElementKind.value) {
        final value =
            (info.elementType as InterfaceType).element as ClassElement;
        for (final column in _generateEmbeddedColumns(
          '',
          value,
          const TypeMapper(),
          const MysqlDialect(),
          false,
        )) {
          if (_identityTypes.contains(column.dartType)) names.add(column.name);
        }
      }
      columns['${rootTable.tableName}_${entry.key}_items'] = names;
    }
    final buffer = StringBuffer(
      '  static const Map<String,Set<String>> _identityColumns = {\n',
    );
    for (final entry in columns.entries) {
      final names = entry.value.map((name) => "'$name'").join(',');
      buffer.writeln("    '${entry.key}':{$names},");
    }
    buffer.writeln('  };');
    buffer.writeln(r'''
  Future<void> _validateIdentitySchema() async {
    for(final table in _identityColumns.entries) {
      final rows = await _connection.query(
        'SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS '
        'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', [table.key]);
      // Missing tables keep the ordinary query/execute error behavior.
      if(rows.isEmpty) continue;
      final actual = {for(final row in rows) row['COLUMN_NAME'] as String:row};
      for(final name in table.value) {
        final column = actual[name];
        final length = column?['CHARACTER_MAXIMUM_LENGTH'];
        if(column?['DATA_TYPE']!='varbinary' || length is! num || length < 1024) {
          throw RepositoryException(
            'Migrate SQL identity column ${table.key}.$name to VARBINARY(1024) before use',
            type:RepositoryExceptionType.constraint);
        }
      }
    }
  }
''');
    return buffer.toString();
  }

  String _generateSaveEntityMethod(TableDefinition table) {
    final methodName = '_save${_toPascalCase(table.tableName)}';
    final jsonKey = _findJsonKeyForTable(table);

    return '''
  /// Saves ${table.tableName} entities.
  Future<void> $methodName($_rootClassName aggregate, Map<String, dynamic> json) async {
    // Delete existing entities for this aggregate
    await _connection.execute(
      'DELETE FROM ${table.tableName} WHERE ${_findParentForeignKeyColumn(table)} = ?',
      [_encodeIdentity(aggregate.id)],
    );

    // Get entities from JSON
    final entitiesJson = json['$jsonKey'];
    if (entitiesJson == null || entitiesJson is! List) return;

    // Save each entity with position to preserve List order
    for (var i = 0; i < entitiesJson.length; i++) {
      final entityJson = entitiesJson[i];
      if (entityJson is! Map<String, dynamic>) continue;

      // Add parent foreign key
      entityJson['${_findParentForeignKeyColumn(table)}'] = _identityCodecs.toJson<$_rootIdentityType>(aggregate.id);

      // Add position to preserve List order
      entityJson['_list_position'] = i;

      // Generate synthetic ID for entity if not present
      if (!entityJson.containsKey('id')) {
        throw const DeserializationException('Stored entity requires its declared identity');
      }

      // Flatten and save
      final flattened = _flattenForTable(entityJson, [], '${table.className}');
      final columns = flattened.keys.toList();
      final values = columns.map((k) => _encodeValue(flattened[k], _types('${table.className}')[k])).toList();

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
  Future<List<Map<String, dynamic>>> $methodName($_rootIdentityType aggregateId) async {
    final rows = await _connection.query(
      'SELECT $selectClause FROM ${table.tableName} WHERE $parentFkColumn = ? ORDER BY _list_position',
      [_encodeIdentity(aggregateId)],
    );

    // Convert rows to JSON and remove the parent FK and position columns
    return rows.map((row) {
      final json = _rowToJson(row, '${table.className}');
      json.remove('$parentFkColumn');
      json.remove('_list_position');
      return json;
    }).toList();
  }''';
  }

  String _generateFlattenForTableMethod() => '''
  /// Selects atomic column leaves from their declared structural JSON paths.
  Map<String,dynamic> _flattenForTable(Map<String,dynamic> json,
      List<String> excludeKeys, [String? context]) {
    final flattened = <String,dynamic>{};
    for(final column in _paths(context).entries) {
      if(excludeKeys.contains(column.value.first)) continue;
      dynamic value = json;
      var found = true;
      for(final segment in column.value) {
        if(value==null) break;
        if(value is! Map || !value.containsKey(segment)) { found=false; break; }
        value = value[segment];
      }
      if(found) flattened[column.key] = value;
    }
    return flattened;
  }
''';

  String _generateRowToJsonMethod() => '''
  /// Restores structural paths without interpreting identity payloads as columns.
  Map<String,dynamic> _rowToJson(Map<String,Object?> row, [String? context]) {
    final json = <String,dynamic>{};
    final created = <Map<String,dynamic>>{};
    final paths = _paths(context);
    for(final entry in row.entries) {
      final path = paths[entry.key] ?? [entry.key];
      var target = json;
      for(final segment in path.take(path.length-1)) {
        if(target[segment] is! Map<String,dynamic>) {
          final nested = <String,dynamic>{};
          target[segment] = nested;
          created.add(nested);
        }
        target = target[segment] as Map<String,dynamic>;
      }
      target[path.last] = _decodeValue(entry.value, entry.key, context);
    }
    dynamic collapse(Map<String,dynamic> map) {
      for(final key in map.keys.toList()) {
        final value = map[key];
        if(value is Map<String,dynamic> && created.contains(value)) {
          map[key] = collapse(value);
        }
      }
      return map.values.every((value)=>value==null) ? null : map;
    }
    for(final key in json.keys.toList()) {
      final value = json[key];
      if(value is Map<String,dynamic> && created.contains(value)) json[key] = collapse(value);
    }
    return json;
  }
''';

  /// Emits field metadata for every row/collection reconstruction context.
  String _generateFieldTypeMapMethod(
    TableDefinition rootTable,
    Map<String, TableDefinition> tables,
  ) {
    const dialect = MysqlDialect();
    const mapper = TypeMapper();
    final contexts = <String, List<ColumnDefinition>>{
      for (final table in tables.values) table.className: table.columns,
    };
    for (final info in _collectionFields.values) {
      if (info.elementKind == ElementKind.value) {
        final element =
            (info.elementType as InterfaceType).element as ClassElement;
        contexts[element.name] =
            _generateEmbeddedColumns('', element, mapper, dialect, false);
      }
    }
    final buffer = StringBuffer();
    buffer.writeln("  static const _rootContext = '${rootTable.className}';");
    buffer.writeln('  static const Map<String,String> _fieldTypes = {');
    for (final column in rootTable.columns) {
      buffer.writeln("    '${column.name}':'${column.dartType}',");
    }
    buffer.writeln('  };');
    buffer.writeln(
      '  static const Map<String,Map<String,String>> _contextTypes = {',
    );
    for (final entry in contexts.entries) {
      buffer.writeln("    '${entry.key}':{");
      for (final column in entry.value) {
        buffer.writeln("      '${column.name}':'${column.dartType}',");
      }
      buffer.writeln('    },');
    }
    buffer.writeln('  };');
    buffer.writeln(
      '  Map<String,String> _types([String? context]) => context==null || context==_rootContext ? _fieldTypes : _contextTypes[context] ?? const {};',
    );
    buffer.writeln(
      '  static const Map<String,Map<String,List<String>>> _contextPaths = {',
    );
    for (final entry in contexts.entries) {
      buffer.writeln("    '${entry.key}':{");
      for (final column in entry.value) {
        final path = (column.jsonPath ?? [column.name])
            .map((part) => "'$part'")
            .join(',');
        buffer.writeln("      '${column.name}':[$path],");
      }
      buffer.writeln('    },');
    }
    buffer.writeln('  };');
    buffer.writeln(
      '  Map<String,List<String>> _paths([String? context]) => _contextPaths[context ?? _rootContext] ?? const {};',
    );
    return buffer.toString();
  }

  String _generateEncodeValueMethod() {
    final buffer = StringBuffer('''
  Object _encodeIdentity($_rootIdentityType identity) =>
      _dialect.encodeIdentityKey(_identityCodecs.toKey<$_rootIdentityType>(identity));

  Object? _encodeValue(dynamic value, [String? dartType]) {
    if(value==null) return null;
    switch(dartType) {
''');
    for (final type in _identityTypes.toList()..sort()) {
      buffer.writeln(
        "      case '$type': return _dialect.encodeIdentityKey(_identityCodecs.toKey<$type>(_identityCodecs.fromJson<$type>(value)));",
      );
    }
    buffer.writeln('''
      case 'DateTime': return _dialect.encodeDateTime(value is DateTime ? value : DateTime.parse(value as String));
      case 'bool': return (value as bool) ? 1 : 0;
      default: return value;
    }
  }
''');
    if (_collectionFields.values
        .any((info) => info.kind == CollectionKind.map)) {
      buffer.writeln('''
  Object? _encodeMapKey(dynamic value, String dartType) {
    switch(dartType) {
''');
      for (final type in _identityTypes.toList()..sort()) {
        buffer.writeln(
          "      case '$type': return _dialect.encodeIdentityKey(_identityCodecs.toKey<$type>(_identityCodecs.fromKey<$type>(value as String)));",
        );
      }
      buffer.writeln('''
      default: return _encodeValue(value,dartType);
    }
  }
''');
    }
    return buffer.toString();
  }

  String _generateDecodeValueMethod() {
    final buffer = StringBuffer('''
  dynamic _decodeValue(Object? value, String fieldName, [String? context]) =>
      _decodeTyped(value, _types(context)[fieldName]);

  dynamic _decodeTyped(Object? value, String? dartType) {
    if(value==null) return null;
    switch(dartType) {
''');
    for (final type in _identityTypes.toList()..sort()) {
      buffer.writeln(
        "      case '$type': return _identityCodecs.toJson<$type>(_identityCodecs.fromKey<$type>(_dialect.decodeIdentityKey(value)));",
      );
    }
    buffer.writeln('''
      case 'DateTime': return _dialect.decodeDateTime(value).toIso8601String();
      case 'bool': return value is bool ? value : (value as int) != 0;
      default: return value;
    }
  }
''');
    if (_collectionFields.values
        .any((info) => info.kind == CollectionKind.map)) {
      buffer.writeln('''
  dynamic _decodeMapKey(Object? value, String dartType) {
    switch(dartType) {
''');
      for (final type in _identityTypes.toList()..sort()) {
        buffer.writeln(
          "      case '$type': final key = _dialect.decodeIdentityKey(value); _identityCodecs.fromKey<$type>(key); return key;",
        );
      }
      buffer.writeln('''
      default: return _decodeTyped(value,dartType);
    }
  }
''');
    }
    return buffer.toString();
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
    final typeParameters = method.typeParameters.isEmpty
        ? ''
        : '<${method.typeParameters.map((parameter) {
            final bound = parameter.bound;
            return bound == null
                ? parameter.name
                : '${parameter.name} extends ${bound.getDisplayString(withNullability: true)}';
          }).join(', ')}>';
    final required = method.parameters
        .where((p) => p.isRequiredPositional)
        .map(_generateParameter)
        .toList();
    final optional = method.parameters
        .where((p) => p.isOptionalPositional)
        .map(_generateParameter)
        .toList();
    final named = method.parameters
        .where((p) => p.isNamed)
        .map(_generateParameter)
        .toList();
    final groups = <String>[
      ...required,
      if (optional.isNotEmpty) '[${optional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ];
    return '$returnType ${method.name}$typeParameters(${groups.join(', ')})';
  }

  String _generateParameter(ParameterElement parameter) {
    final buffer = StringBuffer();
    if (parameter.isRequiredNamed) buffer.write('required ');
    if (parameter.isCovariant) buffer.write('covariant ');
    buffer
      ..write(parameter.type.getDisplayString(withNullability: true))
      ..write(' ${parameter.name}');
    final defaultValue = parameter.defaultValueCode;
    if (defaultValue != null) buffer.write(' = $defaultValue');
    return buffer.toString();
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

  /// Generates a save method using declared element/key types and row context.
  String _generateCollectionSaveMethod(
    String fieldName,
    String tableName,
    CollectionInfo collectionInfo,
    String className,
  ) {
    const q = '`';
    final methodName = '_save${_toPascalCase(fieldName)}';
    final collectionTable = '${tableName}_${fieldName}_items';
    final parent = '${tableName}_id';
    final element =
        collectionInfo.elementType.getDisplayString(withNullability: false);
    final keyType =
        collectionInfo.keyType?.getDisplayString(withNullability: false);
    final entries = collectionInfo.kind == CollectionKind.map
        ? '(collectionValue as Map).entries'
        : '(collectionValue as List).asMap().entries';
    final buffer = StringBuffer('''
  Future<void> $methodName($_rootIdentityType aggregateId, dynamic collectionValue) async {
    final parentKey = _encodeIdentity(aggregateId);
    await _connection.execute('DELETE FROM $q$collectionTable$q WHERE $q$parent$q = ?', [parentKey]);
    if(collectionValue==null) return;
    for(final entry in $entries) {
      final item = entry.value;
''');
    if (collectionInfo.elementKind == ElementKind.primitive) {
      buffer.writeln(
        "      final data = <String,Object?>{'value':_encodeValue(item,'$element')};",
      );
    } else {
      buffer.writeln(
        "      final flat = _flattenForTable(item as Map<String,dynamic>, const [], '$element');",
      );
      buffer.writeln(
        "      final data = <String,Object?>{for(final field in flat.entries) field.key:_encodeValue(field.value,_types('$element')[field.key])};",
      );
    }
    buffer.writeln("      final columns = <String>['$parent',");
    if (collectionInfo.kind == CollectionKind.list) {
      buffer.writeln("        'position',");
    }
    if (collectionInfo.kind == CollectionKind.map) {
      buffer.writeln("        'map_key',");
    }
    buffer.writeln('        ...data.keys];');
    buffer.writeln('      final values = <Object?>[parentKey,');
    if (collectionInfo.kind == CollectionKind.list) {
      buffer.writeln('        entry.key,');
    }
    if (collectionInfo.kind == CollectionKind.map) {
      buffer.writeln("        _encodeMapKey(entry.key,'$keyType'),");
    }
    buffer.writeln('        ...data.values];');
    buffer.writeln('''
      final names = columns.map((column)=>'$q\$column$q').join(', ');
      final placeholders = List.filled(columns.length,'?').join(', ');
      await _connection.execute('INSERT INTO $q$collectionTable$q (\$names) VALUES (\$placeholders)',values);
    }
  }
''');
    return buffer.toString();
  }

  /// Generates a load method with exact parent keys and typed reconstruction.
  String _generateCollectionLoadMethod(
    String fieldName,
    String tableName,
    CollectionInfo collectionInfo,
    String className,
  ) {
    const q = '`';
    final methodName = '_load${_toPascalCase(fieldName)}';
    final collectionTable = '${tableName}_${fieldName}_items';
    final parent = '${tableName}_id';
    final element =
        collectionInfo.elementType.getDisplayString(withNullability: false);
    final keyType =
        collectionInfo.keyType?.getDisplayString(withNullability: false);
    final order = collectionInfo.kind == CollectionKind.list
        ? ' ORDER BY ${q}position$q'
        : '';
    final buffer = StringBuffer('''
  Future<dynamic> $methodName($_rootIdentityType aggregateId) async {
    final rows = await _connection.query('SELECT * FROM $q$collectionTable$q WHERE $q$parent$q = ?$order',[_encodeIdentity(aggregateId)]);
''');
    final map = collectionInfo.kind == CollectionKind.map;
    buffer.writeln(
      map
          ? '    final result = <String,dynamic>{};'
          : '    final result = <dynamic>[];',
    );
    buffer.writeln('    for(final row in rows) {');
    if (collectionInfo.elementKind == ElementKind.primitive) {
      buffer.writeln(
        "      final value = _decodeTyped(row['value'],'$element');",
      );
    } else {
      buffer.writeln(
        "      final filtered = Map<String,Object?>.from(row)..remove('$parent')..remove('position')..remove('map_key');",
      );
      buffer.writeln("      final value = _rowToJson(filtered,'$element');");
    }
    if (map) {
      buffer.writeln(
        "      final key = _decodeMapKey(row['map_key'],'$keyType') as String;",
      );
      buffer.writeln('      result[key] = value;');
    } else {
      buffer.writeln('      result.add(value);');
    }
    buffer.writeln('    }\n    return result;\n  }');
    return buffer.toString();
  }
}
