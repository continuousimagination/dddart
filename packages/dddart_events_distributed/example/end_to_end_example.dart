/// End-to-end example demonstrating bidirectional event flow.
///
/// This example shows:
/// - Server publishes event → Client receives it
/// - Client publishes event → Server receives it
/// - Bidirectional event flow between server and client
///
/// This example runs both server and client in the same process for
/// demonstration purposes. In a real application, they would run in
/// separate processes.
library;

import 'dart:async';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'lib/event_registry.dart';
import 'lib/example_events.dart';
import 'lib/in_memory_event_repository.dart';

void main() async {
  print('=== End-to-End Distributed Events Example ===\n');

  // ========== SERVER SETUP ==========
  print('Setting up server...');

  final serverEventBus = EventBus();
  final repository = InMemoryEventRepository();

  final server = EventBusServer<StoredEvent>(
    localEventBus: serverEventBus,
    eventRepository: repository,
    retentionDuration: const Duration(hours: 24),
    storedEventFactory: StoredEvent.fromDomainEvent,
  );

  // Subscribe to events on server
  server.on<UserCreatedEvent>().listen((event) {
    print('[SERVER] Received UserCreatedEvent: ${event.email}');
  });

  server.on<OrderPurchasedEvent>().listen((event) {
    print('[SERVER] Received OrderPurchasedEvent: \$${event.amount}');
  });

  server.on<OrderPlacedEvent>().listen((event) {
    print('[SERVER] Received OrderPlacedEvent: \$${event.amount}');
  });

  // Set up HTTP endpoints
  final endpoints = EventHttpEndpoints(
    eventRepository: repository,
  );

  final router = Router()
    ..get('/events', endpoints.handleGetEvents)
    ..post(
      '/events',
      (Request request) => endpoints.handlePostEvent(request, server),
    );

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final httpServer = await shelf_io.serve(handler, 'localhost', 8080);
  print(
    '[SERVER] Listening on http://${httpServer.address.host}:${httpServer.port}\n',
  );

  // ========== CLIENT SETUP ==========
  print('Setting up client...');

  final clientEventBus = EventBus();

  final client = EventBusClient(
    localEventBus: clientEventBus,
    serverUrl: 'http://localhost:8080',
    eventRegistry: generatedEventRegistry,
    pollingInterval: const Duration(seconds: 2),
    autoForward: true,
    initialTimestamp: DateTime.now().subtract(const Duration(minutes: 1)),
  );

  // Subscribe to events on client
  client.on<UserCreatedEvent>().listen((event) {
    print('[CLIENT] Received UserCreatedEvent: ${event.email}');
  });

  client.on<OrderPurchasedEvent>().listen((event) {
    print('[CLIENT] Received OrderPurchasedEvent: \$${event.amount}');
  });

  client.on<OrderPlacedEvent>().listen((event) {
    print('[CLIENT] Received OrderPlacedEvent: \$${event.amount}');
  });

  print('[CLIENT] Connected to server\n');

  // ========== DEMONSTRATION ==========
  print('=== Demonstrating Bidirectional Event Flow ===\n');

  // Wait a moment for setup
  await Future<void>.delayed(const Duration(milliseconds: 500));

  // 1. Server publishes event → Client should receive it
  print('1. Server publishes UserCreatedEvent...');
  final serverEvent = UserCreatedEvent(
    aggregateId: UuidValue.generate(),
    email: 'alice@example.com',
    name: 'Alice',
    context: {'userId': 'user-123', 'tenantId': 'tenant-1'},
  );
  server.publish(serverEvent);
  print('   [SERVER] Published UserCreatedEvent\n');

  // Wait for client to poll and receive
  await Future<void>.delayed(const Duration(seconds: 3));

  // 2. Client publishes event → Server should receive it
  print('2. Client publishes OrderPurchasedEvent...');
  final clientEvent = OrderPurchasedEvent(
    aggregateId: UuidValue.generate(),
    amount: 99.99,
    productId: 'product-456',
    context: {'userId': 'user-123', 'tenantId': 'tenant-1'},
  );
  client.publish(clientEvent);
  print('   [CLIENT] Published OrderPurchasedEvent\n');

  // Wait for auto-forward to complete
  await Future<void>.delayed(const Duration(seconds: 1));

  // 3. Server publishes another event
  print('3. Server publishes OrderPlacedEvent...');
  final serverEvent2 = OrderPlacedEvent(
    aggregateId: UuidValue.generate(),
    amount: 149.99,
    productId: 'product-789',
    context: {'userId': 'user-456', 'tenantId': 'tenant-1'},
  );
  server.publish(serverEvent2);
  print('   [SERVER] Published OrderPlacedEvent\n');

  // Wait for client to poll and receive
  await Future<void>.delayed(const Duration(seconds: 3));

  // 4. Client publishes another event
  print('4. Client publishes another UserCreatedEvent...');
  final clientEvent2 = UserCreatedEvent(
    aggregateId: UuidValue.generate(),
    email: 'bob@example.com',
    name: 'Bob',
    context: {'userId': 'user-789', 'tenantId': 'tenant-2'},
  );
  client.publish(clientEvent2);
  print('   [CLIENT] Published UserCreatedEvent\n');

  // Wait for auto-forward to complete
  await Future<void>.delayed(const Duration(seconds: 1));

  // ========== SUMMARY ==========
  print('=== Summary ===');
  print('Total events in repository: ${repository.count}');
  print('\nBidirectional event flow demonstrated successfully!');
  print('- Server events were received by client via polling');
  print('- Client events were forwarded to server via HTTP POST');
  print('- All events were persisted in the repository\n');

  // ========== CLEANUP ==========
  print('Cleaning up...');
  await client.close();
  await server.close();
  await httpServer.close();
  print('Done!');
}
