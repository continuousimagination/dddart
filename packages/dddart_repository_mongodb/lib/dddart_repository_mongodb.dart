/// MongoDB repository implementation for DDDart.
///
/// This library provides code-generated MongoDB repositories for DDDart
/// aggregate roots, leveraging existing JSON serialization from dddart_json
/// and the mongo_dart driver for MongoDB connectivity.
///
/// ## Features
///
/// - **Code Generation**: Automatically generates MongoDB repository
///   implementations from annotated aggregate root classes
/// - **JSON Serialization**: Reuses existing dddart_json serializers for
///   persistence without duplicate serialization logic
/// - **Extensibility**: Generated repositories can be used directly or
///   extended with custom query methods
/// - **AWS DocumentDB**: Compatible with AWS DocumentDB Serverless through
///   standard MongoDB protocol support
/// - **Error Handling**: Comprehensive error mapping to RepositoryException
///   types for consistent error handling
///
/// ## Quick Start
///
/// 1. Add dependencies to your `pubspec.yaml`:
///
/// ```yaml
/// dependencies:
///   dddart: ^1.0.0
///   dddart_json: ^1.0.0
///   dddart_repository_mongodb: ^1.0.0
///   mongo_dart: ^0.10.0
///
/// dev_dependencies:
///   build_runner: ^2.4.0
/// ```
///
/// 2. Annotate your aggregate root:
///
/// ```dart
/// import 'package:dddart/dddart.dart';
/// import 'package:dddart_serialization/dddart_serialization.dart';
/// import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
///
/// @Serializable()
/// @GenerateMongoRepository(collectionName: 'users')
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///
///   User({required this.firstName, required this.lastName});
/// }
///
/// part 'user.g.dart';
/// part 'user.mongo_repository.g.dart';
/// ```
///
/// 3. Generate code:
///
/// ```bash
/// dart run build_runner build
/// ```
///
/// 4. Use the generated repository:
///
/// ```dart
/// final connection = MongoConnection(
///   host: 'localhost',
///   port: 27017,
///   databaseName: 'myapp',
/// );
/// await connection.open();
///
/// final userRepo = UserMongoRepository(connection.database);
///
/// // Create and save
/// final user = User(firstName: 'John', lastName: 'Doe');
/// await userRepo.save(user);
///
/// // Retrieve
/// final retrieved = await userRepo.getById(user.id);
///
/// // Delete
/// await userRepo.deleteById(user.id);
///
/// await connection.close();
/// ```
///
/// ## Custom Query Methods
///
/// Define a custom interface and extend the generated base class:
///
/// ```dart
/// abstract interface class UserRepository implements Repository<User> {
///   Future<User?> findByEmail(String email);
/// }
///
/// @Serializable()
/// @GenerateMongoRepository(implements: UserRepository)
/// class User extends AggregateRoot {
///   final String email;
///   User({required this.email});
/// }
///
/// part 'user.g.dart';
/// part 'user.mongo_repository.g.dart';
///
/// class UserMongoRepository extends UserMongoRepositoryBase {
///   UserMongoRepository(super.database);
///
///   @override
///   Future<User?> findByEmail(String email) async {
///     final doc = await _collection.findOne(where.eq('email', email));
///     if (doc == null) return null;
///     doc['id'] = doc['_id'];
///     doc.remove('_id');
///     return _serializer.fromJson(doc);
///   }
/// }
/// ```
library dddart_repository_mongodb;

// Annotations
export 'src/annotations/generate_mongo_repository.dart';

// Connection management
export 'src/connection/mongo_connection.dart';

// Exceptions
export 'src/exceptions/mongo_repository_exception.dart';
