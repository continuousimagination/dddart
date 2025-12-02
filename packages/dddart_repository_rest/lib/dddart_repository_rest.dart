/// REST API-backed repository implementation for DDDart.
///
/// This library provides code-generated REST repositories for DDDart
/// aggregate roots, enabling distributed domain-driven design architectures
/// where aggregates are persisted via HTTP rather than direct database access.
///
/// ## Features
///
/// - **Code Generation**: Automatically generates REST repository
///   implementations from annotated aggregate root classes
/// - **JSON Serialization**: Reuses existing dddart_json serializers for
///   HTTP request/response bodies
/// - **Authentication**: Integrates with dddart_rest_client for automatic
///   token management and authentication
/// - **Extensibility**: Generated repositories can be used directly or
///   extended with custom query methods
/// - **Error Handling**: Comprehensive HTTP status code mapping to
///   RepositoryException types for consistent error handling
///
/// ## Quick Start
///
/// 1. Add dependencies to your `pubspec.yaml`:
///
/// ```yaml
/// dependencies:
///   dddart: ^1.0.0
///   dddart_json: ^1.0.0
///   dddart_repository_rest: ^0.1.0
///   dddart_rest_client: ^0.1.0
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
/// import 'package:dddart_repository_rest/dddart_repository_rest.dart';
///
/// @Serializable()
/// @GenerateRestRepository(resourcePath: '/users')
/// class User extends AggregateRoot {
///   final String firstName;
///   final String lastName;
///
///   User({required this.firstName, required this.lastName});
/// }
///
/// part 'user.g.dart';
/// part 'user.rest_repository.g.dart';
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
/// final connection = RestConnection(
///   baseUrl: 'https://api.example.com',
/// );
///
/// final userRepo = UserRestRepository(connection);
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
/// connection.dispose();
/// ```
///
/// ## Authentication
///
/// Configure authentication using an AuthProvider:
///
/// ```dart
/// final authProvider = DeviceFlowAuthProvider(
///   clientId: 'your-client-id',
///   authorizationEndpoint: 'https://auth.example.com/authorize',
///   tokenEndpoint: 'https://auth.example.com/token',
/// );
///
/// final connection = RestConnection(
///   baseUrl: 'https://api.example.com',
///   authProvider: authProvider,
/// );
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
/// @GenerateRestRepository(implements: UserRepository)
/// class User extends AggregateRoot {
///   final String email;
///   User({required this.email});
/// }
///
/// part 'user.g.dart';
/// part 'user.rest_repository.g.dart';
///
/// class UserRestRepository extends UserRestRepositoryBase {
///   UserRestRepository(super.connection);
///
///   @override
///   Future<User?> findByEmail(String email) async {
///     try {
///       final response = await _connection.client.get(
///         '$_resourcePath?email=$email',
///       );
///
///       if (response.statusCode == 200) {
///         final json = jsonDecode(response.body) as List<dynamic>;
///         if (json.isEmpty) return null;
///         return _serializer.fromJson(json.first as Map<String, dynamic>);
///       }
///
///       throw _mapHttpException(response.statusCode, response.body);
///     } catch (e) {
///       if (e is RepositoryException) rethrow;
///       throw RepositoryException(
///         'Failed to find user by email: $e',
///         type: RepositoryExceptionType.unknown,
///         cause: e,
///       );
///     }
///   }
/// }
/// ```
library dddart_repository_rest;

// Annotations
export 'src/annotations/generate_rest_repository.dart';

// Connection management
export 'src/connection/rest_connection.dart';
