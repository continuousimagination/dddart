import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart_repository_rest/src/annotations/generate_rest_repository.dart';
import 'package:source_gen/source_gen.dart';

/// Code generator for REST repository implementations.
///
/// This generator processes [GenerateRestRepository] annotations and
/// generates repository implementations that communicate with REST APIs
/// via HTTP.
///
/// The generator validates that:
/// - The annotated element is a class
/// - The class extends AggregateRoot
/// - The class has a @Serializable annotation
///
/// Based on the annotation parameters, it generates either:
/// - A concrete repository class (if no custom interface or only base methods)
/// - An abstract base class (if custom interface with additional methods)
class RestRepositoryGenerator
    extends GeneratorForAnnotation<GenerateRestRepository> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate element is a ClassElement
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @GenerateRestRepository.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Validate class extends AggregateRoot
    if (!_extendsAggregateRoot(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must extend AggregateRoot to use @GenerateRestRepository.',
        element: element,
      );
    }

    // Validate class has @Serializable annotation
    if (!_hasSerializableAnnotation(classElement)) {
      throw InvalidGenerationSourceError(
        'Class $className must be annotated with @Serializable() to use @GenerateRestRepository.',
        element: element,
      );
    }

    // Extract configuration from annotation
    final resourcePath = _extractResourcePath(annotation, className);
    final customInterface = _extractImplementsInterface(annotation);

    // Determine what to generate based on interface analysis
    if (customInterface == null) {
      // No custom interface - generate concrete class
      return _generateConcreteRepository(className, resourcePath);
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
        resourcePath,
        implements: customInterface,
      );
    } else {
      // Interface has custom methods - generate abstract base class
      return _generateAbstractBaseRepository(
        className,
        resourcePath,
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

  /// Extracts the resource path from the annotation or generates a default.
  ///
  /// If `resourcePath` is provided in the annotation, uses that value.
  /// Otherwise, converts the class name to lowercase plural form.
  String _extractResourcePath(ConstantReader annotation, String className) {
    final resourcePath = annotation.peek('resourcePath')?.stringValue;
    return resourcePath ?? _generateResourcePath(className);
  }

  /// Generates a resource path from a class name.
  ///
  /// Converts PascalCase to kebab-case and pluralizes.
  /// Examples:
  /// - User → users
  /// - OrderItem → order-items
  /// - Company → companies
  String _generateResourcePath(String className) {
    // Convert PascalCase to kebab-case
    final kebab = className
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '-${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading dash

    // Simple pluralization
    if (kebab.endsWith('y')) {
      return '${kebab.substring(0, kebab.length - 1)}ies';
    } else if (kebab.endsWith('s') ||
        kebab.endsWith('x') ||
        kebab.endsWith('ch')) {
      return '${kebab}es';
    } else {
      return '${kebab}s';
    }
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

  /// Generates a concrete repository class implementation.
  ///
  /// This is used when:
  /// - No custom interface is specified
  /// - Custom interface only contains base Repository<T> methods
  ///
  /// The generated class can be instantiated directly.
  String _generateConcreteRepository(
    String className,
    String resourcePath, {
    InterfaceType? implements,
  }) {
    final interfaceClause = implements != null
        ? 'implements ${implements.element.name}'
        : 'implements Repository<$className>';

    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated REST repository for [$className] aggregate.',
    );
    buffer.writeln('///');
    buffer.writeln(
      '/// This class can be used directly for basic CRUD operations or extended',
    );
    buffer.writeln('/// to add custom query methods.');
    buffer.writeln('class ${className}RestRepository $interfaceClause {');

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln('  ${className}RestRepository(this._connection);');
    buffer.writeln();

    // Generate fields and getters
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln("  String get _resourcePath => '$resourcePath';");
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
    buffer.writeln(_generateMapHttpExceptionMethod());

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
    String resourcePath, {
    required InterfaceType implements,
    required List<MethodElement> abstractMethods,
  }) {
    final buffer = StringBuffer();

    // Class documentation
    buffer.writeln(
      '/// Generated abstract base REST repository for [$className] aggregate.',
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
      'abstract class ${className}RestRepositoryBase implements ${implements.element.name} {',
    );

    // Constructor
    buffer.writeln('  /// Creates a repository instance.');
    buffer.writeln('  ///');
    buffer.writeln('  /// [connection] - A REST connection to the API server.');
    buffer.writeln('  ${className}RestRepositoryBase(this._connection);');
    buffer.writeln();

    // Generate fields and getters (same as concrete class)
    buffer.writeln('  /// The REST connection instance.');
    buffer.writeln('  final RestConnection _connection;');
    buffer.writeln();
    buffer.writeln('  /// The resource path for $className aggregates.');
    buffer.writeln("  String get _resourcePath => '$resourcePath';");
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

    buffer.writeln(_generateMapHttpExceptionMethod());
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

  /// Generates the getById method implementation.
  String _generateGetByIdMethod(String className) {
    return '''
  @override
  Future<$className> getById(UuidValue id) async {
    try {
      final response = await _connection.client.get(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${id.uuid}'),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _serializer.fromJson(json);
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to retrieve $className: \$e',
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
      final json = _serializer.toJson(aggregate);
      final body = jsonEncode(json);
      
      final response = await _connection.client.put(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${aggregate.id.uuid}'),
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
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
      final response = await _connection.client.delete(
        Uri.parse('\${_connection.baseUrl}\$_resourcePath/\${id.uuid}'),
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }
      
      throw _mapHttpException(response.statusCode, response.body);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      throw RepositoryException(
        'Failed to delete $className: \$e',
        type: RepositoryExceptionType.unknown,
        cause: e,
      );
    }
  }''';
  }

  /// Generates the HTTP exception mapping helper method.
  String _generateMapHttpExceptionMethod() {
    return r'''
  /// Maps HTTP status codes to RepositoryException types.
  RepositoryException _mapHttpException(int statusCode, String body) {
    switch (statusCode) {
      case 404:
        return RepositoryException(
          'Resource not found',
          type: RepositoryExceptionType.notFound,
        );
      case 409:
        return RepositoryException(
          'Duplicate resource',
          type: RepositoryExceptionType.duplicate,
        );
      case 408:
      case 504:
        return RepositoryException(
          'Request timeout',
          type: RepositoryExceptionType.timeout,
        );
      case >= 500:
        return RepositoryException(
          'Server error: $statusCode',
          type: RepositoryExceptionType.connection,
        );
      default:
        return RepositoryException(
          'HTTP error $statusCode: $body',
          type: RepositoryExceptionType.unknown,
        );
    }
  }''';
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

/// Builder function for build_runner integration.
///
/// This function is referenced in build.yaml and called by build_runner
/// to create the generator.
Builder restRepositoryBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [RestRepositoryGenerator()],
    'rest_repository',
  );
}
