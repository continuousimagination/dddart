import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Analyzes aggregate root classes to discover all referenced types.
///
/// This class performs graph traversal on aggregate root classes to discover
/// all types that need to be persisted to the database. It handles:
/// - Nested entities within aggregates
/// - Value objects embedded in aggregates and entities
/// - Circular references between types
/// - Dependency ordering for table creation
///
/// The analyzer uses depth-first search to traverse the object graph and
/// produces a topologically sorted list of types where dependencies appear
/// before the types that depend on them.
///
/// Example:
/// ```dart
/// final analyzer = RelationshipAnalyzer();
/// final types = analyzer.analyzeAggregate(orderClass);
/// // Returns: [Money, Address, OrderItem, Order]
/// // (value objects and entities before aggregate root)
/// ```
class RelationshipAnalyzer {
  /// Creates a relationship analyzer.
  const RelationshipAnalyzer();

  /// Discovers all types referenced by an aggregate root.
  ///
  /// Performs a depth-first traversal of the aggregate's object graph to
  /// discover all referenced types. The returned list is ordered such that
  /// dependencies appear before the types that depend on them (topological sort).
  ///
  /// This ordering is critical for:
  /// - Creating tables in the correct order (dependencies first)
  /// - Saving data in the correct order (foreign key constraints)
  /// - Deleting data with proper cascade handling
  ///
  /// Handles circular references by detecting cycles and breaking them to
  /// avoid infinite loops. When a cycle is detected, the analyzer skips
  /// revisiting the type.
  ///
  /// Example:
  /// ```dart
  /// // Given: Order -> OrderItem -> Money
  /// final types = analyzer.analyzeAggregate(orderClass);
  /// // Returns: [Money, OrderItem, Order]
  /// ```
  ///
  /// Returns a list of [ClassElement]s in dependency order.
  List<ClassElement> analyzeAggregate(ClassElement aggregateRoot) {
    final discovered = <ClassElement>{};
    final visiting = <ClassElement>{};
    final ordered = <ClassElement>[];

    void visit(ClassElement element) {
      // Already processed
      if (discovered.contains(element)) {
        return;
      }

      // Circular reference detected - skip to avoid infinite loop
      if (visiting.contains(element)) {
        return;
      }

      visiting.add(element);

      // Visit all referenced types first (depth-first)
      for (final field in element.fields) {
        final fieldType = field.type;
        final referencedClass = _getReferencedClass(fieldType);

        if (referencedClass != null && !_isPrimitiveType(referencedClass)) {
          visit(referencedClass);
        }
      }

      visiting.remove(element);
      discovered.add(element);
      ordered.add(element);
    }

    visit(aggregateRoot);
    return ordered;
  }

  /// Determines the relationship type between two classes.
  ///
  /// Analyzes a field to determine what kind of relationship it represents:
  /// - **One-to-One**: Single reference to another class
  /// - **One-to-Many**: List of entities (e.g., `List<OrderItem>`)
  /// - **Many-to-One**: Reference from child to parent (inverse of one-to-many)
  ///
  /// The relationship type determines how the data is stored:
  /// - One-to-One: Foreign key column in this table
  /// - One-to-Many: Separate table with foreign key back to parent
  /// - Many-to-One: Foreign key column in child table
  ///
  /// Example:
  /// ```dart
  /// // Order has List<OrderItem> items
  /// final type = analyzer.getRelationshipType(itemsField);
  /// // Returns: RelationshipType.oneToMany
  /// ```
  RelationshipType getRelationshipType(FieldElement field) {
    final fieldType = field.type;

    // Check if it's a List<T>
    if (fieldType.isDartCoreList) {
      return RelationshipType.oneToMany;
    }

    // Check if it's a single reference to a class
    final referencedClass = _getReferencedClass(fieldType);
    if (referencedClass != null && !_isPrimitiveType(referencedClass)) {
      return RelationshipType.oneToOne;
    }

    // Default to one-to-one for other cases
    return RelationshipType.oneToOne;
  }

  /// Checks if a type is a value object (no identity).
  ///
  /// Value objects are classes that extend the `Value` base class from dddart.
  /// They represent descriptive aspects of the domain with no conceptual identity.
  ///
  /// In the SQL schema, value objects are **embedded** into their parent tables
  /// with prefixed column names rather than getting their own tables.
  ///
  /// Example:
  /// ```dart
  /// class Money extends Value {
  ///   final double amount;
  ///   final String currency;
  /// }
  /// // isValueObject(Money) returns true
  /// // Money fields are embedded: totalAmount_amount, totalAmount_currency
  /// ```
  ///
  /// Returns `true` if [element] extends `Value`.
  bool isValueObject(ClassElement element) {
    return _extendsClass(element, 'Value');
  }

  /// Checks if a type is an entity (has identity).
  ///
  /// Entities are classes that extend the `Entity` base class from dddart.
  /// They have a unique identity that persists over time, even if their
  /// attributes change.
  ///
  /// In the SQL schema, entities get their own tables with primary keys.
  ///
  /// Note: `AggregateRoot` extends `Entity`, so this returns `true` for
  /// both entities and aggregate roots.
  ///
  /// Example:
  /// ```dart
  /// class OrderItem extends Entity {
  ///   final UuidValue productId;
  ///   final int quantity;
  /// }
  /// // isEntity(OrderItem) returns true
  /// // OrderItem gets its own table: order_items
  /// ```
  ///
  /// Returns `true` if [element] extends `Entity` or `AggregateRoot`.
  bool isEntity(ClassElement element) {
    return _extendsClass(element, 'Entity');
  }

  /// Checks if a type is an aggregate root.
  ///
  /// Aggregate roots are classes that extend the `AggregateRoot` base class
  /// from dddart. They serve as the entry point to an aggregate - a cluster
  /// of domain objects that can be treated as a single unit.
  ///
  /// In the SQL schema:
  /// - Aggregate roots get their own tables
  /// - Entities within the aggregate have foreign keys with CASCADE DELETE
  /// - References to other aggregates are just UUID columns (no foreign keys)
  ///
  /// Example:
  /// ```dart
  /// class Order extends AggregateRoot {
  ///   final List<OrderItem> items; // Entities within aggregate
  ///   final UuidValue customerId;  // Reference to another aggregate
  /// }
  /// // isAggregateRoot(Order) returns true
  /// ```
  ///
  /// Returns `true` if [element] extends `AggregateRoot`.
  bool isAggregateRoot(ClassElement element) {
    return _extendsClass(element, 'AggregateRoot');
  }

  /// Checks if a class extends a specific base class.
  ///
  /// Recursively checks the inheritance hierarchy.
  bool _extendsClass(ClassElement element, String baseClassName) {
    // Check the class itself
    if (element.name == baseClassName) {
      return true;
    }

    // Check superclass
    final supertype = element.supertype;
    if (supertype != null) {
      final superElement = supertype.element;
      if (superElement.name == baseClassName) {
        return true;
      }
      // Recursively check superclass hierarchy if it's a ClassElement
      if (superElement is ClassElement) {
        return _extendsClass(superElement, baseClassName);
      }
    }

    return false;
  }

  /// Extracts the ClassElement from a DartType.
  ///
  /// Handles both direct class references and generic types like List<T>.
  ClassElement? _getReferencedClass(DartType type) {
    // Skip collection types - they're handled by CollectionAnalyzer
    if (type is InterfaceType) {
      if (type.isDartCoreList || type.isDartCoreSet || type.isDartCoreMap) {
        // Extract element type from collection
        final typeArgs = type.typeArguments;
        if (typeArgs.isNotEmpty) {
          // For List<T> and Set<T>, use first type argument
          // For Map<K, V>, use second type argument (value type)
          final elementType = type.isDartCoreMap && typeArgs.length > 1
              ? typeArgs[1]
              : typeArgs.first;

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
      final element = type.element;
      if (element is ClassElement) {
        return element;
      }
    }

    return null;
  }

  /// Checks if a class represents a primitive type.
  ///
  /// Primitive types don't need their own tables.
  bool _isPrimitiveType(ClassElement element) {
    final name = element.name;
    return name == 'String' ||
        name == 'int' ||
        name == 'double' ||
        name == 'bool' ||
        name == 'DateTime' ||
        name == 'UuidValue' ||
        name == 'Type' || // Dart built-in type
        name == 'Object'; // Dart built-in type
  }

  /// Determines if a field is a collection type.
  ///
  /// Returns `true` if the field is a List, Set, or Map.
  ///
  /// Example:
  /// ```dart
  /// // For field: List<int> favoriteNumbers
  /// analyzer.isCollection(field); // true
  /// // For field: String name
  /// analyzer.isCollection(field); // false
  /// ```
  bool isCollection(FieldElement field) {
    final type = field.type;
    return type.isDartCoreList || type.isDartCoreSet || type.isDartCoreMap;
  }

  /// Gets the collection kind (List, Set, Map).
  ///
  /// Returns the kind of collection, or `null` if not a collection.
  ///
  /// Example:
  /// ```dart
  /// // For field: List<int> favoriteNumbers
  /// analyzer.getCollectionKind(field.type); // CollectionKind.list
  /// // For field: Set<String> tags
  /// analyzer.getCollectionKind(field.type); // CollectionKind.set
  /// ```
  CollectionKind? getCollectionKind(DartType type) {
    if (type.isDartCoreList) {
      return CollectionKind.list;
    } else if (type.isDartCoreSet) {
      return CollectionKind.set;
    } else if (type.isDartCoreMap) {
      return CollectionKind.map;
    }
    return null;
  }

  /// Extracts element type from List<T> or Set<T>.
  ///
  /// Returns the type argument T from a List<T> or Set<T> type.
  /// Returns `null` if the type is not a List or Set, or has no type arguments.
  ///
  /// Example:
  /// ```dart
  /// // For type: List<int>
  /// analyzer.getElementType(listType); // int type
  /// // For type: Set<String>
  /// analyzer.getElementType(setType); // String type
  /// ```
  DartType? getElementType(DartType collectionType) {
    if (collectionType is InterfaceType) {
      if (collectionType.isDartCoreList || collectionType.isDartCoreSet) {
        final typeArgs = collectionType.typeArguments;
        if (typeArgs.isNotEmpty) {
          return typeArgs.first;
        }
      }
    }
    return null;
  }

  /// Extracts key and value types from Map<K, V>.
  ///
  /// Returns a tuple of (keyType, valueType) from a Map<K, V> type.
  /// Returns `(null, null)` if the type is not a Map or has insufficient type arguments.
  ///
  /// Example:
  /// ```dart
  /// // For type: Map<String, int>
  /// final (keyType, valueType) = analyzer.getMapTypes(mapType);
  /// // keyType is String, valueType is int
  /// ```
  (DartType?, DartType?) getMapTypes(DartType mapType) {
    if (mapType is InterfaceType && mapType.isDartCoreMap) {
      final typeArgs = mapType.typeArguments;
      if (typeArgs.length >= 2) {
        return (typeArgs[0], typeArgs[1]);
      }
    }
    return (null, null);
  }
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

/// Types of relationships between classes.
enum RelationshipType {
  /// Single reference (one-to-one).
  oneToOne,

  /// List of entities (one-to-many).
  oneToMany,

  /// Reference from child to parent (many-to-one).
  manyToOne,
}
