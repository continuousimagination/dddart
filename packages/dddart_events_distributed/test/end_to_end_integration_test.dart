/// End-to-end integration tests for distributed events system.
///
/// Tests the complete flow of events between server and client components,
/// including event publishing, persistence, polling, catch-up after disconnect,
/// and authorization filtering.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
// Import example events and repository
import 'package:dddart_events_distributed_example/example_events.dart';
import 'package:dddart_events_distributed_example/in_memory_event_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('End-to-End Integration Tests', () {
    late InMemoryEventRepository serverRepository;
    late EventBusServer<StoredEvent> server;
    late EventBus serverEventBus;
    late http.Client httpClient;
    late EventHttpEndpoints<StoredEvent> endpoints;
    late shelf.Handler handler;
    late int serverPort;
    late String serverUrl;

    setUp(() async {
      // Set up server components
      serverRepository = InMemoryEventRepository();
      serverEventBus = EventBus();
      server = EventBusServer<StoredEvent>(
        localEventBus: serverEventBus,
        eventRepository: serverRepository,
        storedEventFactory: StoredEvent.fromDomainEvent,
      );

      // Set up HTTP endpoints
      endpoints = EventHttpEndpoints<StoredEvent>(
        eventRepository: serverRepository,
      );

      // Create HTTP handler
      handler = (shelf.Request request) async {
        if (request.method == 'GET' && request.url.path == 'events') {
          return endpoints.handleGetEvents(request);
        } else if (request.method == 'POST' && request.url.path == 'events') {
          return endpoints.handlePostEvent(request, server);
        }
        return shelf.Response.notFound('Not found');
      };

      // Start HTTP server on random port
      final serverInstance = await shelf_io.serve(handler, 'localhost', 0);
      serverPort = serverInstance.port;
      serverUrl = 'http://localhost:$serverPort';

      httpClient = http.Client();

      // Store server instance for cleanup
      addTearDown(() async {
        await serverInstance.close(force: true);
      });
    });

    tearDown(() async {
      await server.close();
      httpClient.close();
      serverRepository.clear();
    });

    test(
      'server publishes event, client receives it',
      () async {
        // Requirements: 2.5, 6.4, 6.5
        // Arrange: Create event registry for client
        final eventRegistry =
            <String, DomainEvent Function(Map<String, dynamic>)>{
          'UserCreatedEvent': UserCreatedEvent.fromJson,
          'OrderPlacedEvent': OrderPlacedEvent.fromJson,
        };

        final clientEventBus = EventBus();
        final receivedEvents = <DomainEvent>[];

        // Subscribe to events on client
        clientEventBus.on<UserCreatedEvent>().listen(receivedEvents.add);

        // Create client with short polling interval
        final client = EventBusClient(
          localEventBus: clientEventBus,
          serverUrl: serverUrl,
          eventRegistry: eventRegistry,
          pollingInterval: const Duration(milliseconds: 100),
          httpClient: httpClient,
        );

        // Act: Publish event on server
        final event = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'test@example.com',
          name: 'Test User',
        );

        server.publish(event);

        // Wait for event to be persisted and polled
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Assert: Client should have received the event
        expect(receivedEvents, hasLength(1));
        expect(receivedEvents.first, isA<UserCreatedEvent>());
        final received = receivedEvents.first as UserCreatedEvent;
        expect(received.email, equals('test@example.com'));
        expect(received.name, equals('Test User'));

        await client.close();
        await clientEventBus.close();
      },
    );

    test(
      'client publishes event, server receives it',
      () async {
        // Requirements: 3.1, 6.4, 6.5
        // Arrange: Create client with auto-forward enabled
        final eventRegistry =
            <String, DomainEvent Function(Map<String, dynamic>)>{
          'UserCreatedEvent': UserCreatedEvent.fromJson,
          'OrderPlacedEvent': OrderPlacedEvent.fromJson,
        };

        final clientEventBus = EventBus();
        final serverReceivedEvents = <DomainEvent>[];

        // Subscribe to events on server
        serverEventBus.on<UserCreatedEvent>().listen(serverReceivedEvents.add);

        final client = EventBusClient(
          localEventBus: clientEventBus,
          serverUrl: serverUrl,
          eventRegistry: eventRegistry,
          pollingInterval: const Duration(milliseconds: 100),
          autoForward: true,
          httpClient: httpClient,
        );

        // Act: Publish event on client
        final event = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'client@example.com',
          name: 'Client User',
        );

        client.publish(event);

        // Wait for event to be forwarded and persisted
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Assert: Event should be in server repository
        final storedEvents = await serverRepository.findAll();
        expect(storedEvents, hasLength(1));
        expect(storedEvents.first.eventType, equals('UserCreatedEvent'));

        // Parse the stored event JSON
        final eventData = jsonDecode(storedEvents.first.eventJson);
        expect(eventData['email'], equals('client@example.com'));
        expect(eventData['name'], equals('Client User'));

        await client.close();
        await clientEventBus.close();
      },
    );

    test(
      'catch-up after simulated disconnect',
      () async {
        // Requirements: 2.5, 4.1, 4.2, 4.3
        // Arrange: Publish events while client is "disconnected"
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@example.com',
          name: 'User 1',
        );
        final event2 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 99.99,
          productId: 'product-123',
        );
        final event3 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user2@example.com',
          name: 'User 2',
        );

        // Publish events to server
        server.publish(event1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        server.publish(event2);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        server.publish(event3);

        // Wait for persistence
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Create client that starts polling from before the events
        final eventRegistry =
            <String, DomainEvent Function(Map<String, dynamic>)>{
          'UserCreatedEvent': UserCreatedEvent.fromJson,
          'OrderPlacedEvent': OrderPlacedEvent.fromJson,
        };

        final clientEventBus = EventBus();
        final receivedEvents = <DomainEvent>[];

        clientEventBus.on<DomainEvent>().listen(receivedEvents.add);

        // Start client with initial timestamp before events were published
        final initialTimestamp =
            DateTime.now().subtract(const Duration(minutes: 1));
        final client = EventBusClient(
          localEventBus: clientEventBus,
          serverUrl: serverUrl,
          eventRegistry: eventRegistry,
          pollingInterval: const Duration(milliseconds: 100),
          initialTimestamp: initialTimestamp,
          httpClient: httpClient,
        );

        // Wait for client to catch up
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Assert: Client should have received all three events
        expect(receivedEvents, hasLength(3));
        expect(receivedEvents[0], isA<UserCreatedEvent>());
        expect(receivedEvents[1], isA<OrderPlacedEvent>());
        expect(receivedEvents[2], isA<UserCreatedEvent>());

        final user1 = receivedEvents[0] as UserCreatedEvent;
        expect(user1.email, equals('user1@example.com'));

        final order = receivedEvents[1] as OrderPlacedEvent;
        expect(order.amount, equals(99.99));

        final user2 = receivedEvents[2] as UserCreatedEvent;
        expect(user2.email, equals('user2@example.com'));

        await client.close();
        await clientEventBus.close();
      },
    );

    test(
      'authorization filtering blocks unauthorized events',
      () async {
        // Requirements: 4.1, 4.2, 4.3
        // Arrange: Set up server with authorization filter
        final filteredRepository = InMemoryEventRepository();
        final filteredEventBus = EventBus();
        final filteredServer = EventBusServer<StoredEvent>(
          localEventBus: filteredEventBus,
          eventRepository: filteredRepository,
          storedEventFactory: StoredEvent.fromDomainEvent,
        );

        // Authorization filter: only allow events for specific user
        bool authFilter(StoredEvent event, shelf.Request request) {
          final allowedUserId = request.headers['x-user-id'];
          return event.userId == allowedUserId;
        }

        final filteredEndpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: filteredRepository,
          authorizationFilter: authFilter,
        );

        Future<shelf.Response> filteredHandler(shelf.Request request) async {
          if (request.method == 'GET' && request.url.path == 'events') {
            return filteredEndpoints.handleGetEvents(request);
          } else if (request.method == 'POST' && request.url.path == 'events') {
            return filteredEndpoints.handlePostEvent(request, filteredServer);
          }
          return shelf.Response.notFound('Not found');
        }

        final filteredServerInstance = await shelf_io.serve(
          filteredHandler,
          'localhost',
          0,
        );
        final filteredServerUrl =
            'http://localhost:${filteredServerInstance.port}';

        // Publish events with different user IDs
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@example.com',
          name: 'User 1',
          context: {'userId': 'user-123'},
        );
        final event2 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user2@example.com',
          name: 'User 2',
          context: {'userId': 'user-456'},
        );
        final event3 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user3@example.com',
          name: 'User 3',
          context: {'userId': 'user-123'},
        );

        filteredServer.publish(event1);
        filteredServer.publish(event2);
        filteredServer.publish(event3);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Poll with user-123 credentials
        final response = await httpClient.get(
          Uri.parse('$filteredServerUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {'x-user-id': 'user-123'},
        );

        // Assert: Should only receive events for user-123
        expect(response.statusCode, equals(200));
        final events = jsonDecode(response.body) as List;
        expect(events, hasLength(2));
        expect(events[0]['userId'], equals('user-123'));
        expect(events[1]['userId'], equals('user-123'));

        // Cleanup
        await filteredServer.close();
        await filteredServerInstance.close(force: true);
      },
    );
  });
}
