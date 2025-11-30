/// Code generator for DynamoDB repository implementations.
library;

// ignore_for_file: deprecated_member_use, avoid_redundant_argument_values

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_dynamodb/src/annotations/generate_dynamo_repository.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function for the DynamoDB repository generator.
///
/// This function is referenced in build.yaml and creates the builder
/// that generates DynamoDB repository implementations.
///
/// The builder uses [SharedPartBuilder] to generate `.dynamo_repository.g.dart`
/// files for classes annotated with [@GenerateDynamoRepository].
Builder dynamoRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [DynamoRepositoryGenerator()],
    'dynamo_repository',
  );
}

/// Generator for DynamoDB repository implementations.
///
/// This generator processes classes annotated with [GenerateDynamoRepository]
/// and generates DynamoDB repository implementations that leverage existing
/// JSON serialization from dddart_json.
class DynamoRepositoryGenerator
    extends GeneratorForAnnotation<GenerateDynamoRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateDynamoRepository.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use '
        '@GenerateDynamoRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use '
        '@GenerateDynamoRepository.',
        element: element,
      );
    }

    // Extract configuration from annotation
    final tableName = _extractTableName(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    // Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - generate concrete class
      return _generateConcreteRepository(className, tableName);
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
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - generate abstract base class
      return _generateAbstractBaseRepository(
        className,
        tableName,
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
  ///
  /// This includes methods from the interface itself and all superinterfaces
  /// (including Repository<T>), but excludes methods from Object and other
  /// system classes.
  List<MethodElement> _getInterfaceMethods(InterfaceType interfaceType) {
    final methods = <MethodElement>[];

    // Get methods from the interface itself
    methods.addAll(interfaceType.methods);

    // Get methods from all superinterfaces (including Repository<T>)
    // but exclude Object and system classes
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
  ///
  /// Examples:
  /// - User → user
  /// - UserProfile → user_profile
  /// - OrderItem → order_item
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className) {
    return '''
  @override
  Future<$className> getById(UuidValue id) async {
    try {
      final response = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );
      
      if (response.item == null || response.item!.isEmpty) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Convert DynamoDB AttributeValue map to JSON
      final json = AttributeValueConverter.attributeMapToJsonMap(response.item!);
      
      return _serializer.fromJson(json);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'getById');
    }
  }''';
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(String className) {
    return '''
  @override
  Future<void> save($className aggregate) async {
    try {
      final json = _serializer.toJson(aggregate);
      
      // Convert JSON to DynamoDB AttributeValue map
      final item = AttributeValueConverter.jsonMapToAttributeMap(json);
      
      // Upsert operation using PutItem
      await _connection.client.putItem(
        tableName: tableName,
        item: item,
      );
    } catch (e) {
      throw _mapDynamoException(e, 'save');
    }
  }''';
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className) {
    return '''
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      // First check if item exists
      final getResponse = await _connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );
      
      if (getResponse.item == null || getResponse.item!.isEmpty) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Delete the item
      await _connection.client.deleteItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.toString())},
      );
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw _mapDynamoException(e, 'deleteById');
    }
  }''';
  }

  /// Generates the DynamoDB exception mapping helper method.
  String _generateMapDynamoExceptionMethod() {
    return r'''
  /// Maps DynamoDB exceptions to RepositoryException types.
  RepositoryException _mapDynamoException(
    Object error,
    String operation,
  ) {
    final errorString = error.toString();
    
    // Map ResourceNotFoundException to notFound
    if (errorString.contains('ResourceNotFoundException')) {
      return RepositoryException(
        'Resource not found during $operation: $errorString',
        type: RepositoryExceptionType.notFound,
        cause: error,
      );
    }
    
    // Map ConditionalCheckFailedException to duplicate
    if (errorString.contains('ConditionalCheckFailedException')) {
      return RepositoryException(
        'Conditional check failed during $operation: $errorString',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }
    
    // Map network/connectivity errors to connection
    if (errorString.contains('connection') || 
        errorString.contains('network') ||
        errorString.contains('SocketException')) {
      return RepositoryException(
        'Connection error during $operation: $errorString',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }
    
    // Map timeout errors to timeout
    if (errorString.contains('timeout') || errorString.contains('TimeoutException')) {
      return RepositoryException(
        'Timeout during $operation: $errorString',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }
    
    // All other errors map to unknown
    return RepositoryException(
      'DynamoDB error during $operation: $errorString',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }''';
  }

  /// Generates table creation utility methods.
  ///
  /// Includes:
  /// - createTable: Instance method to execute table creation
  /// - getCreateTableCommand: Returns AWS CLI command string
  /// - getCloudFormationTemplate: Returns CloudFormation YAML snippet
  String _generateTableCreationMethods(String className, String tableName) {
    return '''
  /// Creates the DynamoDB table for this repository.
  ///
  /// This is a convenience method that uses the connection's client to
  /// create the table with the appropriate schema.
  ///
  /// Throws [RepositoryException] if table creation fails.
  ///
  /// Example:
  /// ```dart
  /// final repo = ${className}DynamoRepository(connection);
  /// await repo.createTable();
  /// ```
  Future<void> createTable() async {
    try {
      await _connection.client.createTable(
        tableName: tableName,
        keySchema: [
          KeySchemaElement(
            attributeName: 'id',
            keyType: KeyType.hash,
          ),
        ],
        attributeDefinitions: [
          AttributeDefinition(
            attributeName: 'id',
            attributeType: ScalarAttributeType.s,
          ),
        ],
        billingMode: BillingMode.payPerRequest,
      );
    } catch (e) {
      throw _mapDynamoException(e, 'createTable');
    }
  }

  /// Returns an AWS CLI command to create this table.
  ///
  /// This command can be executed in a terminal to create the table
  /// using the AWS CLI.
  ///
  /// Example:
  /// ```dart
  /// final command = ${className}DynamoRepository.getCreateTableCommand('$tableName');
  /// print(command);
  /// // Copy and paste into terminal
  /// ```
  static String getCreateTableCommand(String tableName) {
    return \'\'\'
aws dynamodb create-table \\\\
  --table-name \$tableName \\\\
  --attribute-definitions AttributeName=id,AttributeType=S \\\\
  --key-schema AttributeName=id,KeyType=HASH \\\\
  --billing-mode PAY_PER_REQUEST
\'\'\'.trim();
  }

  /// Returns a CloudFormation YAML template for this table.
  ///
  /// This template can be included in a CloudFormation stack to
  /// provision the table as infrastructure as code.
  ///
  /// Example:
  /// ```dart
  /// final template = ${className}DynamoRepository.getCloudFormationTemplate('$tableName');
  /// print(template);
  /// // Add to CloudFormation template
  /// ```
  static String getCloudFormationTemplate(String tableName) {
    return \'\'\'
Resources:
  \\\${tableName.split(\'_\').map((s) => s[0].toUpperCase() + s.substring(1)).join()}Table:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: \$tableName
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      BillingMode: PAY_PER_REQUEST
\'\'\'.trim();
  }''';
  }

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String tableName, {
    InterfaceType? implements,
  }) {
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated DynamoDB repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or',
    );
    buffer.writeln('/// extended');
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class ${className}DynamoRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A DynamoDB connection instance.');
    buffer.writeln('  ${className}DynamoRepository(this._connection);');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The DynamoDB connection instance.');
    buffer.writeln('  final DynamoConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();

    // Generate CRUD methods
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapDynamoExceptionMethod());
    buffer.writeln();

    // Generate table creation utilities
    buffer.writeln(_generateTableCreationMethods(className, tableName));

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates an abstract base repository class.
  ///
  /// This is used when a custom interface contains methods beyond the base
  /// Repository<T> interface. The generated abstract class implements the
  /// base CRUD methods and declares custom methods as abstract.
  ///
  /// Developers must extend this class and implement the custom methods.
  String _generateAbstractBaseRepository(
    String className,
    String tableName, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated abstract base DynamoDB repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This abstract class implements the base Repository<$className> methods',
    );
    buffer.writeln(
      '/// (getById, save, deleteById) and declares custom methods as abstract.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// Extend this class and implement the abstract methods to complete',
    );
    buffer.writeln('/// the repository implementation.');
    buffer.writeln(
      'abstract class ${className}DynamoRepositoryBase implements ${implements.element.name} {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A DynamoDB connection instance.');
    buffer.writeln('  ${className}DynamoRepositoryBase(this._connection);');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The DynamoDB connection instance.');
    buffer.writeln('  final DynamoConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The table name for $className aggregates.');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();

    // Generate concrete implementations of base Repository methods
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();

    // Generate exception mapping helper
    buffer.writeln(_generateMapDynamoExceptionMethod());
    buffer.writeln();

    // Generate table creation utilities
    buffer.writeln(_generateTableCreationMethods(className, tableName));
    buffer.writeln();

    // Add abstract method declarations for custom methods
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

  /// Generates a method signature from a MethodElement.
  ///
  /// Includes return type, method name, and parameters with types.
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
