/// Annotation to mark aggregate roots for MongoDB repository generation.
///
/// This annotation triggers code generation that creates a MongoDB repository
/// implementation for the annotated aggregate root class. The generated
/// repository implements the `Repository<T>` interface from the dddart package
/// and uses the aggregate's JSON serializer from dddart_json for persistence.
///
/// ## Requirements
///
/// The annotated class must:
/// - Extend `AggregateRoot` from the dddart package
/// - Be annotated with `@Serializable()` from dddart_serialization
///
/// ## Basic Usage (Concrete Repository)
///
/// When used without a custom interface, generates a concrete repository class
/// that can be instantiated directly:
///
/// ```dart
/// @Serializable()
/// @GenerateMongoRepository(collectionName: 'users')
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///
///   User({required this.firstName, required this.lastName});
/// }
///
/// part 'user.mongo_repository.g.dart';
///
/// // Usage:
/// final connection = MongoConnection(
///   host: 'localhost',
///   port: 27017,
///   databaseName: 'myapp',
/// );
/// await connection.open();
///
/// final userRepo = UserMongoRepository(connection.database);
/// await userRepo.save(user);
/// final retrieved = await userRepo.getById(user.id);
/// ```
///
/// ## Custom Interface (Abstract Base Repository)
///
/// When a custom interface is specified that contains methods beyond the base
/// `Repository<T>` interface, an abstract base class is generated. The
/// developer must extend this base class and implement the custom methods:
///
/// ```dart
/// // Define custom repository interface
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> findByEmail(String email);
///   Future<List<User>> findByLastName(String lastName);
/// }
///
/// @Serializable()
/// @GenerateMongoRepository(
///   collectionName: 'users',
///   implements: UserRepository,
/// )
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///   final String email;
///
///   User({
///     required this.firstName,
///     required this.lastName,
///     required this.email,
///   });
/// }
///
/// part 'user.mongo_repository.g.dart';
///
/// // Extend generated base class and implement custom methods
/// class UserMongoRepository extends UserMongoRepositoryBase {
///   UserMongoRepository(super.database);
///
///   @override
///   Future<User?> findByEmail(String email) async {
///     final doc = await _collection.findOne(where.eq('email', email));
///     if (doc == null) return null;
///
///     doc['id'] = doc['_id'];
///     doc.remove('_id');
///     return _serializer.fromJson(doc);
///   }
///
///   @override
///   Future<List<User>> findByLastName(String lastName) async {
///     final docs = await _collection
///         .find(where.eq('lastName', lastName))
///         .toList();
///
///     return docs.map((doc) {
///       doc['id'] = doc['_id'];
///       doc.remove('_id');
///       return _serializer.fromJson(doc);
///     }).toList();
///   }
/// }
/// ```
///
/// ## Collection Naming
///
/// If [collectionName] is not provided, the collection name defaults to the
/// aggregate class name converted to snake_case. For example:
/// - `User` → `users`
/// - `OrderItem` → `order_items`
/// - `UserProfile` → `user_profiles`
///
/// ## Implementation Swapping
///
/// By defining a custom interface, you can swap repository implementations
/// for different environments:
///
/// ```dart
/// // Production: MongoDB implementation
/// UserRepository repo = UserMongoRepository(database);
///
/// // Testing: In-memory implementation
/// UserRepository repo = InMemoryRepository<User>();
///
/// // Client-side: REST API implementation (future package)
/// UserRepository repo = UserRestRepository(apiClient);
/// ```
class GenerateMongoRepository {
  /// Creates a GenerateMongoRepository annotation.
  ///
  /// [collectionName] - Optional custom collection name. If not provided,
  /// the aggregate class name will be converted to snake_case.
  /// For example, `UserProfile` becomes `user_profiles`.
  ///
  /// [implements] - Optional custom repository interface. If provided and
  /// the interface contains custom methods beyond `Repository<T>`, an abstract
  /// base class will be generated requiring the developer to implement
  /// custom methods. If the interface only contains base `Repository<T>`
  /// methods, a concrete class will be generated.
  const GenerateMongoRepository({
    this.collectionName,
    this.implements,
  });

  /// The MongoDB collection name for this aggregate type.
  ///
  /// If null, defaults to snake_case conversion of the class name.
  /// Must follow MongoDB collection naming rules:
  /// - Cannot be empty
  /// - Cannot contain null characters
  /// - Cannot start with "system."
  final String? collectionName;

  /// The custom repository interface to implement.
  ///
  /// If null, generates a concrete class implementing `Repository<T>`.
  ///
  /// If provided:
  /// - Interface contains only base `Repository<T>` methods → generates
  ///   concrete class implementing the interface
  /// - Interface contains custom methods → generates abstract base class
  ///   with concrete implementations of base methods and abstract
  ///   declarations of custom methods
  final Type? implements;
}
