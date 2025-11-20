/// Code generator for MongoDB repository implementations.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_mongodb/src/annotations/generate_mongo_repository.dart';
import 'package:source_gen/source_gen.dart';

/// Builder factory function for the MongoDB repository generator.
///
/// This function is referenced in build.yaml and creates the builder
/// that generates MongoDB repository implementations.
///
/// The builder uses [SharedPartBuilder] to generate `.mongo_repository.g.dart`
/// files for classes annotated with [@GenerateMongoRepository].
Builder mongoRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [MongoRepositoryGenerator()],
    'mongo_repository',
  );
}

/// Generator for MongoDB repository implementations.
///
/// This generator processes classes annotated with [GenerateMongoRepository]
/// and generates MongoDB repository implementations that leverage existing
/// JSON serialization from dddart_json.
class MongoRepositoryGenerator
    extends GeneratorForAnnotation<GenerateMongoRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Task 4.1: Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateMongoRepository.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Task 4.2: Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateMongoRepository.',
        element: element,
      );
    }

    // Task 4.2: Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateMongoRepository.',
        element: element,
      );
    }

    // Task 4.3: Extract configuration from annotation
    final collectionName = _extractCollectionName(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    // Task 4.4: Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - will generate concrete class in task 5
      return _generateConcreteRepository(className, collectionName);
    }

    // Task 4.4: Analyze interface to determine if abstract base is needed
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
        .where((m) =>
            !baseRepositoryMethods.contains(m.name) &&
            !objectMethods.contains(m.name) &&
            !m.isOperator &&
            !m.isStatic,)
        .toList();

    if (customMethods.isEmpty) {
      // Interface only has base Repository methods - will generate concrete class
      return _generateConcreteRepository(
        className,
        collectionName,
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - will generate abstract base class in task 6
      return _generateAbstractBaseRepository(
        className,
        collectionName,
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

  /// Extracts the collection name from the annotation or generates a default.
  ///
  /// If `collectionName` is provided in the annotation, uses that value.
  /// Otherwise, converts the class name to snake_case.
  String _extractCollectionName(ConstantReader annotation, String className) {
    final collectionName = annotation.peek('collectionName')?.stringValue;
    return collectionName ?? _toSnakeCase(className);
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

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String collectionName, {
    InterfaceType? implements,
  }) {
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated MongoDB repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or extended',
    );
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class ${className}MongoRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [database] - An open MongoDB database connection.');
    buffer.writeln('  ${className}MongoRepository(this._database);');
    buffer.writeln();

    // Task 5.1: Generate fields and getters
    buffer.writeln('  /// The MongoDB database instance (library-private).');
    buffer.writeln('  final Db _database;');
    buffer.writeln();
    buffer.writeln('  /// The collection name for $className aggregates.');
    buffer.writeln("  String get collectionName => '$collectionName';");
    buffer.writeln();
    buffer
        .writeln('  /// Gets the MongoDB collection for this aggregate type.');
    buffer.writeln(
      '  DbCollection get _collection => _database.collection(collectionName);',
    );
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();

    // Task 5.2: Generate getById method
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    // Task 5.3: Generate save method
    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    // Task 5.4: Generate deleteById method
    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();

    // Task 5.5: Generate exception mapping helper
    buffer.writeln(_generateMapMongoExceptionMethod());

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className) {
    return '''
  @override
  Future<$className> getById(UuidValue id) async {
    try {
      final doc = await _collection.findOne(where.eq('_id', id.toString()));
      
      if (doc == null) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
      
      // Convert MongoDB _id back to id field for deserialization
      doc['id'] = doc['_id'];
      doc.remove('_id');
      
      return _serializer.fromJson(doc);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve $className with ID \$id: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the save method implementation.
  String _generateSaveMethod(String className) {
    return '''
  @override
  Future<void> save($className aggregate) async {
    try {
      final doc = _serializer.toJson(aggregate);
      
      // Use aggregate's id as MongoDB _id
      doc['_id'] = doc['id'];
      doc.remove('id');
      
      // Upsert operation
      await _collection.replaceOne(
        where.eq('_id', aggregate.id.toString()),
        doc,
        upsert: true,
      );
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'save');
    } catch (e) {
      throw RepositoryException(
        'Failed to save $className: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the deleteById method implementation.
  String _generateDeleteByIdMethod(String className) {
    return '''
  @override
  Future<void> deleteById(UuidValue id) async {
    try {
      final result = await _collection.deleteOne(where.eq('_id', id.toString()));
      
      if (result.nRemoved == 0) {
        throw RepositoryException(
          '$className with ID \$id not found',
          type: RepositoryExceptionType.notFound,
        );
      }
    } on RepositoryException {
      rethrow;
    } on MongoDartError catch (e) {
      throw _mapMongoException(e, 'deleteById');
    } catch (e) {
      throw RepositoryException(
        'Failed to delete $className with ID \$id: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the MongoDB exception mapping helper method.
  String _generateMapMongoExceptionMethod() {
    return r'''
  /// Maps MongoDB exceptions to RepositoryException types.
  RepositoryException _mapMongoException(
    MongoDartError error,
    String operation,
  ) {
    // Map specific MongoDB error codes to RepositoryExceptionType
    if (error.message?.contains('duplicate key') ?? false) {
      return RepositoryException(
        'Duplicate key error during $operation: ${error.message}',
        type: RepositoryExceptionType.duplicate,
        cause: error,
      );
    }
    
    if (error.message?.contains('connection') ?? false) {
      return RepositoryException(
        'Connection error during $operation: ${error.message}',
        type: RepositoryExceptionType.connection,
        cause: error,
      );
    }
    
    if (error.message?.contains('timeout') ?? false) {
      return RepositoryException(
        'Timeout during $operation: ${error.message}',
        type: RepositoryExceptionType.timeout,
        cause: error,
      );
    }
    
    return RepositoryException(
      'MongoDB error during $operation: ${error.message}',
      type: RepositoryExceptionType.unknown,
      cause: error,
    );
  }''';
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
    String collectionName, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    final buffer = StringBuffer();

    // Task 6.1: Class documentation
    buffer.writeln(
      '/// Generated abstract base MongoDB repository for [$className] aggregate.',
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
      'abstract class ${className}MongoRepositoryBase implements ${implements.element.name} {',
    );

    // Task 6.1: Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [database] - An open MongoDB database connection.');
    buffer.writeln('  ${className}MongoRepositoryBase(this._database);');
    buffer.writeln();

    // Task 6.1: Generate fields and getters (same as concrete class)
    buffer.writeln('  /// The MongoDB database instance (library-private).');
    buffer.writeln('  final Db _database;');
    buffer.writeln();
    buffer.writeln('  /// The collection name for $className aggregates.');
    buffer.writeln("  String get collectionName => '$collectionName';");
    buffer.writeln();
    buffer
        .writeln('  /// Gets the MongoDB collection for this aggregate type.');
    buffer.writeln(
      '  DbCollection get _collection => _database.collection(collectionName);',
    );
    buffer.writeln();
    buffer.writeln('  /// The JSON serializer for $className aggregates.');
    buffer.writeln('  final _serializer = ${className}JsonSerializer();');
    buffer.writeln();

    // Task 6.1: Generate concrete implementations of base Repository methods
    buffer.writeln(_generateGetByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateSaveMethod(className));
    buffer.writeln();

    buffer.writeln(_generateDeleteByIdMethod(className));
    buffer.writeln();

    buffer.writeln(_generateMapMongoExceptionMethod());
    buffer.writeln();

    // Task 6.2: Add abstract method declarations for custom methods
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
