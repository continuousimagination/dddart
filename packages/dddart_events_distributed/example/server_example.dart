/// Example demonstrating EventBusServer with HTTP endpoints.
///
/// This example shows how to:
/// - Set up EventBusServer with in-memory repository
/// - Configure HTTP endpoints with shelf
/// - Publish events and persist them automatically
/// - Query events via HTTP GET
/// - Receive events via HTTP POST
library;

import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'lib/example_events.dart';

void main() async {
  print('Starting EventBusServer example...\n');

  // Create local EventBus
  final eventBus = EventBus();

  // Create in-memory event repository
  final repository = InMemoryEventRepository();

  // Create EventBusServer with automatic persistence
  final server = EventBusServer<StoredEvent>(
    localEventBus: eventBus,
    eventRepository: repository,
    retentionDuration: const Duration(hours: 24),
    storedEventFactory: StoredEvent.fromDomainEvent,
  );

  // Subscribe to events locally
  server.on<UserCreatedEvent>().listen((event) {
    print('Server received UserCreatedEvent: ${event.email}');
  });

  server.on<OrderPurchasedEvent>().listen((event) {
    print('Server received OrderPurchasedEvent: \$${event.amount}');
  });

  // Create HTTP endpoints
  final endpoints = EventHttpEndpoints(
    eventRepository: repository,
    // Optional: Add authorization filter
    authorizationFilter: (event, request) {
      // Example: Filter by tenant ID from header
      final tenantId = request.headers['x-tenant-id'];
      if (tenantId == null) {
        return true; // No filter if no tenant header
      }
      return event.tenantId == tenantId;
    },
  );

  // Set up HTTP routes
  final router = Router()
    ..get('/events', endpoints.handleGetEvents)
    ..post(
      '/events',
      (Request request) => endpoints.handlePostEvent(request, server),
    );

  // Add logging middleware
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  // Start HTTP server
  final httpServer = await shelf_io.serve(handler, 'localhost', 8080);
  print(
    'Server listening on http://${httpServer.address.host}:${httpServer.port}\n',
  );

  // Publish some example events
  print('Publishing example events...\n');

  // Event 1: User created
  final userEvent = UserCreatedEvent(
    aggregateId: UuidValue.generate(),
    email: 'alice@example.com',
    name: 'Alice',
    context: {
      'userId': 'user-123',
      'tenantId': 'tenant-1',
    },
  );
  server.publish(userEvent);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // Event 2: Order purchased
  final orderEvent = OrderPurchasedEvent(
    aggregateId: UuidValue.generate(),
    amount: 99.99,
    productId: 'product-456',
    context: {
      'userId': 'user-123',
      'tenantId': 'tenant-1',
    },
  );
  server.publish(orderEvent);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // Event 3: Another user created (different tenant)
  final user2Event = UserCreatedEvent(
    aggregateId: UuidValue.generate(),
    email: 'bob@example.com',
    name: 'Bob',
    context: {
      'userId': 'user-456',
      'tenantId': 'tenant-2',
    },
  );
  server.publish(user2Event);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  print('\nPublished ${repository.count} events');
  print('\nServer is running. Try these commands:\n');
  print('  # Get all events:');
  print(
    '  curl "http://localhost:8080/events?since=2024-01-01T00:00:00.000Z"\n',
  );
  print('  # Get events for tenant-1:');
  print(
    '  curl -H "x-tenant-id: tenant-1" "http://localhost:8080/events?since=2024-01-01T00:00:00.000Z"\n',
  );
  print('  # Post a new event:');
  print(
    '  curl -X POST http://localhost:8080/events -H "Content-Type: application/json" -d \'{"id":"...","createdAt":"...","aggregateId":"...","eventType":"UserCreatedEvent","eventJson":"..."}\'\n',
  );
  print('Press Ctrl+C to stop the server.\n');

  // Keep server running
  await ProcessSignal.sigint.watch().first;

  print('\nShutting down...');
  await httpServer.close();
  await server.close();
  print('Server stopped.');
}
