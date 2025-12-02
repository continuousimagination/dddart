# dddart_repository_rest Examples

This directory contains comprehensive examples demonstrating how to use the `dddart_repository_rest` package.

## Prerequisites

Before running these examples, you need:

1. **Dart SDK** 3.5.0 or later
2. **A REST API server** running locally (see [Setting Up a Test Server](#setting-up-a-test-server))
3. **Generated code** (run `dart run build_runner build` in this directory)

## Examples Overview

### 1. Basic CRUD Example (`basic_crud_example.dart`)

Demonstrates fundamental CRUD operations:
- Creating a REST connection
- Saving aggregates (CREATE)
- Retrieving aggregates by ID (READ)
- Updating aggregates (UPDATE)
- Deleting aggregates (DELETE)
- Handling not found exceptions

**Run:**
```bash
dart run basic_crud_example.dart
```

### 2. Authentication Example (`authentication_example.dart`)

Shows how to work with authenticated REST APIs:
- Setting up a REST connection with an AuthProvider
- Static token authentication
- Device flow authentication (for CLI tools)
- Automatic token refresh
- Handling authentication errors

**Run:**
```bash
dart run authentication_example.dart
```

### 3. Custom Repository Example (`custom_repository_example.dart`)

Demonstrates extending generated repositories with custom query methods:
- Defining a custom repository interface
- Extending the generated base class
- Implementing domain-specific queries
- Using protected members (`_connection`, `_serializer`, `_resourcePath`)
- Consistent error handling with `_mapHttpException`

**Run:**
```bash
dart run custom_repository_example.dart
```

### 4. Error Handling Example (`error_handling_example.dart`)

Comprehensive error handling patterns:
- Different repository exception types (notFound, duplicate, connection, timeout)
- Retry strategies with exponential backoff
- Graceful degradation patterns
- Error logging and context
- Input validation and defensive programming

**Run:**
```bash
dart run error_handling_example.dart
```

## Setting Up a Test Server

To run these examples, you need a REST API server. Here's how to set one up using `dddart_rest`:

### Option 1: Quick Test Server

Create a file `test_server.dart`:

```dart
import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';

import 'lib/user.dart';
import 'lib/product.dart';

Future<void> main() async {
  final server = HttpServer(port: 8080);

  // Register user resource
  server.registerResource(
    CrudResource<User, void>(
      path: '/users',
      repository: InMemoryRepository<User>(),
      serializers: {'application/json': UserJsonSerializer()},
    ),
  );

  // Register product resource
  server.registerResource(
    CrudResource<Product, void>(
      path: '/products',
      repository: InMemoryRepository<Product>(),
      serializers: {'application/json': ProductJsonSerializer()},
    ),
  );

  await server.start();
  print('Test server running at http://localhost:8080');
  print('Press Ctrl+C to stop');
}
```

Run the server:
```bash
dart run test_server.dart
```

### Option 2: Using Docker

If you have a containerized REST API:

```bash
docker run -p 8080:8080 your-rest-api-image
```

### Option 3: Remote Server

Update the `baseUrl` in the examples to point to your remote server:

```dart
final connection = RestConnection(
  baseUrl: 'https://api.example.com',
);
```

## Generating Code

The example domain models require code generation. Run:

```bash
# From the example directory
dart run build_runner build

# Or with conflict resolution
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/user.g.dart` - User serializer and repository
- `lib/product.g.dart` - Product serializer and repository

## Domain Models

### User (`lib/user.dart`)

A simple aggregate representing a user:
- `firstName`: User's first name
- `lastName`: User's last name
- `email`: User's email address

Generated repository: `UserRestRepository`

### Product (`lib/product.dart`)

An aggregate with a custom repository interface:
- `name`: Product name
- `description`: Product description
- `price`: Product price
- `category`: Product category

Custom interface: `ProductRepository`
- `findByCategory(String category)`: Find products by category
- `findByPriceRange(double min, double max)`: Find products in price range

Generated base class: `ProductRestRepositoryBase`
Custom implementation: `ProductRestRepository` (in `custom_repository_example.dart`)

## Common Issues

### Connection Refused

**Problem:** `Connection refused` or `Failed to connect`

**Solution:** Make sure your REST API server is running on the correct port (default: 8080)

### 404 Not Found

**Problem:** All requests return 404

**Solution:** 
- Verify the server has the correct resource paths registered
- Check that resource paths match the annotation (`/users`, `/products`)

### Code Generation Errors

**Problem:** Generated files are missing or outdated

**Solution:**
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Authentication Errors

**Problem:** 401 Unauthorized or 403 Forbidden

**Solution:**
- Verify your AuthProvider is returning valid tokens
- Check that the server expects the authentication format you're using
- Ensure the token has the required scopes/permissions

## Learning Path

We recommend exploring the examples in this order:

1. **Basic CRUD** - Understand fundamental operations
2. **Error Handling** - Learn to handle failures gracefully
3. **Custom Repository** - Extend with domain-specific queries
4. **Authentication** - Add security to your API calls

## Additional Resources

- [Package README](../README.md) - Complete package documentation
- [DDDart Documentation](../../dddart/README.md) - Core DDD concepts
- [dddart_rest Documentation](../../dddart_rest/README.md) - REST API server
- [dddart_rest_client Documentation](../../dddart_rest_client/README.md) - HTTP client

## Support

If you encounter issues:

1. Check the [troubleshooting section](../README.md#troubleshooting) in the main README
2. Verify your server is running and accessible
3. Ensure generated code is up to date
4. Check that all dependencies are properly installed

## Contributing

Found an issue or want to improve an example? Contributions are welcome!
