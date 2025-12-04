import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Analyzes collection fields in aggregate roots and entities.
///
/// This class provides utilities for detecting and analyzing collection types
/// (List, Set, Map) and their element types. It determines whether collections
/// contain primitives, value objects, or entities, which affects how they are
/// stored in the database.
///
/// Example:
/// ```dart
/// final analyzer = CollectionAnalyzer();
/// final info = analyzer.analyzeCollection(favoriteNumbersField);
/// // Returns: CollectionInfo with kind=list, elementKind=primitive
/// ```
class CollectionAnalyzer {
  /// Creates a collection analyzer.
  const CollectionAnalyzer();

  /// Analyzes a collection field to determine its characteristics.
  ///
  /// Examines the field type to determine:
  /// - Collection kind (List, Set, or Map)
  /// - Element type and kind (primitive, value object, or entity)
  /// - Key type for maps
  ///
  /// Returns `null` if the field is not a collection type.
  ///
  /// Example:
  /// ```dart
  /// // For field: List<int> favoriteNumbers
  /// final info = analyzer.analyzeCollection(field);
  /// // info.kind == CollectionKind.list
  /// // info.elementKind == ElementKind.primitive
  /// // info.elementType is int
  /// ```
  CollectionInfo? analyzeCollection(FieldElement field) {
    final fieldType = field.type;

    // Check for List<T>
    if (fieldType.isDartCoreList) {
      final elementType = _getListElementType(fieldType);
      if (elementType == null) return null;

      final elementKind = _determineElementKind(elementType);
      return CollectionInfo(
        kind: CollectionKind.list,
        elementKind: elementKind,
        elementType: elementType,
        keyType: null,
      );
    }

    // Check for Set<T>
    if (fieldType.isDartCoreSet) {
      final elementType = _getSetElementType(fieldType);
      if (elementType == null) return null;

      final elementKind = _determineElementKind(elementType);
      return CollectionInfo(
        kind: CollectionKind.set,
        elementKind: elementKind,
        elementType: elementType,
        keyType: null,
      );
    }

    // Check for Map<K, V>
    if (fieldType.isDartCoreMap) {
      final types = _getMapTypes(fieldType);
      if (types.$1 == null || types.$2 == null) return null;

      final keyType = types.$1!;
      final valueType = types.$2!;
      final elementKind = _determineElementKind(valueType);

      return CollectionInfo(
        kind: CollectionKind.map,
        elementKind: elementKind,
        elementType: valueType,
        keyType: keyType,
      );
    }

    return null;
  }

  /// Checks if a type is a supported primitive type.
  ///
  /// Primitive types are basic Dart types that can be directly stored
  /// in SQL columns without additional tables.
  ///
  /// Supported primitives:
  /// - `int`, `double`, `String`, `bool`
  /// - `DateTime` (stored as TEXT or DATETIME depending on dialect)
  /// - `UuidValue` (stored as BLOB or BINARY)
  ///
  /// Example:
  /// ```dart
  /// analyzer.isPrimitiveType(intType); // true
  /// analyzer.isPrimitiveType(stringType); // true
  /// analyzer.isPrimitiveType(customClassType); // false
  /// ```
  bool isPrimitiveType(DartType type) {
    if (type is! InterfaceType) return false;

    final element = type.element;
    if (element is! ClassElement) return false;

    final name = element.name;
    return name == 'String' ||
        name == 'int' ||
        name == 'double' ||
        name == 'bool' ||
        name == 'DateTime' ||
        name == 'UuidValue';
  }

  /// Checks if a type is a value object.
  ///
  /// Value objects extend the `Value` base class from dddart.
  /// They are embedded into parent tables with prefixed columns.
  ///
  /// Example:
  /// ```dart
  /// class Money extends Value {
  ///   final double amount;
  ///   final String currency;
  /// }
  /// analyzer.isValueObject(moneyElement); // true
  /// ```
  bool isValueObject(ClassElement element) {
    return _extendsClass(element, 'Value');
  }

  /// Checks if a type is an entity.
  ///
  /// Entities extend the `Entity` base class from dddart.
  /// They have identity and get their own tables.
  ///
  /// Note: `AggregateRoot` extends `Entity`, so this returns `true`
  /// for both entities and aggregate roots.
  ///
  /// Example:
  /// ```dart
  /// class OrderItem extends Entity {
  ///   final int quantity;
  /// }
  /// analyzer.isEntity(orderItemElement); // true
  /// ```
  bool isEntity(ClassElement element) {
    return _extendsClass(element, 'Entity');
  }

  /// Validates that a collection type is supported.
  ///
  /// Throws [UnsupportedError] if the collection type is not supported:
  /// - Nested collections (e.g., `List<List<int>>`)
  /// - Dynamic collections (e.g., `List<dynamic>`)
  /// - Object collections (e.g., `List<Object>`)
  /// - Value objects as map keys (e.g., `Map<Money, int>`)
  /// - Collections of aggregate roots
  ///
  /// Example:
  /// ```dart
  /// analyzer.validateCollectionType(listOfIntType); // OK
  /// analyzer.validateCollectionType(listOfListType); // throws
  /// ```
  void validateCollectionType(DartType collectionType) {
    // Check for nested collections
    if (collectionType is InterfaceType) {
      if (collectionType.isDartCoreList ||
          collectionType.isDartCoreSet ||
          collectionType.isDartCoreMap) {
        final typeArgs = collectionType.typeArguments;
        for (final typeArg in typeArgs) {
          if (typeArg is InterfaceType) {
            if (typeArg.isDartCoreList ||
                typeArg.isDartCoreSet ||
                typeArg.isDartCoreMap) {
              throw UnsupportedError(
                'Nested collections are not supported. '
                'Type: $collectionType. '
                'Suggestion: Wrap the inner collection in a Value object or Entity.',
              );
            }
          }
        }

        // Check for dynamic or Object types
        for (final typeArg in typeArgs) {
          if (typeArg is DynamicType) {
            throw UnsupportedError(
              'Collections with dynamic types are not supported. '
              'Type: $collectionType. '
              'Suggestion: Use a specific type like List<int> or List<String>.',
            );
          }
          if (typeArg is InterfaceType) {
            final element = typeArg.element;
            if (element is ClassElement && element.name == 'Object') {
              throw UnsupportedError(
                'Collections with Object types are not supported. '
                'Type: $collectionType. '
                'Suggestion: Use a specific type like List<int> or List<String>.',
              );
            }
          }
        }

        // Check for value objects as map keys
        if (collectionType.isDartCoreMap && typeArgs.length >= 2) {
          final keyType = typeArgs[0];
          if (keyType is InterfaceType) {
            final keyElement = keyType.element;
            if (keyElement is ClassElement && isValueObject(keyElement)) {
              throw UnsupportedError(
                'Value objects cannot be used as map keys. '
                'Type: $collectionType. '
                "Suggestion: Use a primitive type as the key, or use the entity's ID.",
              );
            }
          }
        }

        // Check for aggregate roots in collections
        for (final typeArg in typeArgs) {
          if (typeArg is InterfaceType) {
            final element = typeArg.element;
            if (element is ClassElement && _isAggregateRoot(element)) {
              throw UnsupportedError(
                'Collections of aggregate roots violate aggregate boundaries. '
                'Type: $collectionType. '
                'Suggestion: Store aggregate IDs instead: List<UuidValue>.',
              );
            }
          }
        }
      }
    }
  }

  /// Extracts the element type from List<T>.
  DartType? _getListElementType(DartType listType) {
    if (listType is InterfaceType && listType.isDartCoreList) {
      final typeArgs = listType.typeArguments;
      if (typeArgs.isNotEmpty) {
        return typeArgs.first;
      }
    }
    return null;
  }

  /// Extracts the element type from Set<T>.
  DartType? _getSetElementType(DartType setType) {
    if (setType is InterfaceType && setType.isDartCoreSet) {
      final typeArgs = setType.typeArguments;
      if (typeArgs.isNotEmpty) {
        return typeArgs.first;
      }
    }
    return null;
  }

  /// Extracts key and value types from Map<K, V>.
  (DartType?, DartType?) _getMapTypes(DartType mapType) {
    if (mapType is InterfaceType && mapType.isDartCoreMap) {
      final typeArgs = mapType.typeArguments;
      if (typeArgs.length >= 2) {
        return (typeArgs[0], typeArgs[1]);
      }
    }
    return (null, null);
  }

  /// Determines the element kind (primitive, value, or entity).
  ElementKind _determineElementKind(DartType elementType) {
    if (isPrimitiveType(elementType)) {
      return ElementKind.primitive;
    }

    if (elementType is InterfaceType) {
      final element = elementType.element;
      if (element is ClassElement) {
        if (isValueObject(element)) {
          return ElementKind.value;
        }
        if (isEntity(element)) {
          return ElementKind.entity;
        }
      }
    }

    // Default to primitive for unknown types
    return ElementKind.primitive;
  }

  /// Checks if a class extends a specific base class.
  bool _extendsClass(ClassElement element, String baseClassName) {
    if (element.name == baseClassName) {
      return true;
    }

    final supertype = element.supertype;
    if (supertype != null) {
      final superElement = supertype.element;
      if (superElement.name == baseClassName) {
        return true;
      }
      if (superElement is ClassElement) {
        return _extendsClass(superElement, baseClassName);
      }
    }

    return false;
  }

  /// Checks if a class is an aggregate root.
  bool _isAggregateRoot(ClassElement element) {
    return _extendsClass(element, 'AggregateRoot');
  }
}

/// Information about a collection field.
class CollectionInfo {
  /// Creates collection information.
  const CollectionInfo({
    required this.kind,
    required this.elementKind,
    required this.elementType,
    required this.keyType,
  });

  /// The kind of collection (list, set, or map).
  final CollectionKind kind;

  /// The kind of element (primitive, value, or entity).
  final ElementKind elementKind;

  /// The Dart type of the collection elements.
  final DartType elementType;

  /// The Dart type of map keys (null for List and Set).
  final DartType? keyType;
}

/// Types of collections.
enum CollectionKind {
  /// List collection (ordered, allows duplicates).
  list,

  /// Set collection (unordered, unique elements).
  set,

  /// Map collection (key-value pairs).
  map,
}

/// Types of collection elements.
enum ElementKind {
  /// Primitive type (int, String, etc.).
  primitive,

  /// Value object (extends Value).
  value,

  /// Entity (extends Entity).
  entity,
}
