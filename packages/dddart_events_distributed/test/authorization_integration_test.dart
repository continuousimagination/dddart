/// Authorization integration tests for distributed events system.
///
/// Tests event filtering based on user context, tenant context, and
/// verifies that no filter returns all events.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
// Import example events
import 'package:dddart_events_distributed_example/example_events.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('Authorization Integration Tests', () {
    late InMemoryEventRepository repository;
    late EventBusServer<StoredEvent> server;
    late EventBus eventBus;
    late http.Client httpClient;

    setUp(() {
      repository = InMemoryEventRepository();
      eventBus = EventBus();
      server = EventBusServer<StoredEvent>(
        localEventBus: eventBus,
        eventRepository: repository,
        storedEventFactory: StoredEvent.fromDomainEvent,
      );
      httpClient = http.Client();
    });

    tearDown(() async {
      await server.close();
      httpClient.close();
      repository.clear();
    });

    test(
      'events filtered by user context',
      () async {
        // Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3
        // Arrange: Create authorization filter based on userId
        bool userAuthFilter(StoredEvent event, shelf.Request request) {
          final requestUserId = request.headers['x-user-id'];
          return event.userId == requestUserId;
        }

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
          authorizationFilter: userAuthFilter,
        );

        Future<shelf.Response> handler(shelf.Request request) async {
          if (request.method == 'GET' && request.url.path == 'events') {
            return endpoints.handleGetEvents(request);
          }
          return shelf.Response.notFound('Not found');
        }

        final serverInstance = await shelf_io.serve(handler, 'localhost', 0);
        final serverUrl = 'http://localhost:${serverInstance.port}';

        // Publish events with different user IDs
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'alice@example.com',
          name: 'Alice',
          context: {'userId': 'user-alice'},
        );
        final event2 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'bob@example.com',
          name: 'Bob',
          context: {'userId': 'user-bob'},
        );
        final event3 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 50,
          productId: 'product-1',
          context: {'userId': 'user-alice'},
        );
        final event4 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 75,
          productId: 'product-2',
          context: {'userId': 'user-bob'},
        );

        server.publish(event1);
        server.publish(event2);
        server.publish(event3);
        server.publish(event4);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Request events as user-alice
        final aliceResponse = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {'x-user-id': 'user-alice'},
        );

        // Assert: Should only receive Alice's events
        expect(aliceResponse.statusCode, equals(200));
        final aliceEvents = jsonDecode(aliceResponse.body) as List;
        expect(aliceEvents, hasLength(2));
        expect(aliceEvents.every((e) => e['userId'] == 'user-alice'), isTrue);

        // Act: Request events as user-bob
        final bobResponse = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {'x-user-id': 'user-bob'},
        );

        // Assert: Should only receive Bob's events
        expect(bobResponse.statusCode, equals(200));
        final bobEvents = jsonDecode(bobResponse.body) as List;
        expect(bobEvents, hasLength(2));
        expect(bobEvents.every((e) => e['userId'] == 'user-bob'), isTrue);

        // Cleanup
        await serverInstance.close(force: true);
      },
    );

    test(
      'events filtered by tenant context',
      () async {
        // Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3
        // Arrange: Create authorization filter based on tenantId
        bool tenantAuthFilter(StoredEvent event, shelf.Request request) {
          final requestTenantId = request.headers['x-tenant-id'];
          return event.tenantId == requestTenantId;
        }

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
          authorizationFilter: tenantAuthFilter,
        );

        Future<shelf.Response> handler(shelf.Request request) async {
          if (request.method == 'GET' && request.url.path == 'events') {
            return endpoints.handleGetEvents(request);
          }
          return shelf.Response.notFound('Not found');
        }

        final serverInstance = await shelf_io.serve(handler, 'localhost', 0);
        final serverUrl = 'http://localhost:${serverInstance.port}';

        // Publish events with different tenant IDs
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@tenant-a.com',
          name: 'User 1',
          context: {'tenantId': 'tenant-a'},
        );
        final event2 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user2@tenant-b.com',
          name: 'User 2',
          context: {'tenantId': 'tenant-b'},
        );
        final event3 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 100,
          productId: 'product-1',
          context: {'tenantId': 'tenant-a'},
        );
        final event4 = PaymentProcessedEvent(
          aggregateId: UuidValue.generate(),
          orderId: 'order-1',
          amount: 100,
          status: 'completed',
          context: {'tenantId': 'tenant-b'},
        );
        final event5 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 200,
          productId: 'product-2',
          context: {'tenantId': 'tenant-a'},
        );

        server.publish(event1);
        server.publish(event2);
        server.publish(event3);
        server.publish(event4);
        server.publish(event5);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Request events for tenant-a
        final tenantAResponse = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {'x-tenant-id': 'tenant-a'},
        );

        // Assert: Should only receive tenant-a events
        expect(tenantAResponse.statusCode, equals(200));
        final tenantAEvents = jsonDecode(tenantAResponse.body) as List;
        expect(tenantAEvents, hasLength(3));
        expect(tenantAEvents.every((e) => e['tenantId'] == 'tenant-a'), isTrue);

        // Act: Request events for tenant-b
        final tenantBResponse = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {'x-tenant-id': 'tenant-b'},
        );

        // Assert: Should only receive tenant-b events
        expect(tenantBResponse.statusCode, equals(200));
        final tenantBEvents = jsonDecode(tenantBResponse.body) as List;
        expect(tenantBEvents, hasLength(2));
        expect(tenantBEvents.every((e) => e['tenantId'] == 'tenant-b'), isTrue);

        // Cleanup
        await serverInstance.close(force: true);
      },
    );

    test(
      'no filter returns all events',
      () async {
        // Requirements: 4.5, 5.1, 5.2, 5.3
        // Arrange: Create endpoints WITHOUT authorization filter
        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
          // No authorizationFilter provided
        );

        Future<shelf.Response> handler(shelf.Request request) async {
          if (request.method == 'GET' && request.url.path == 'events') {
            return endpoints.handleGetEvents(request);
          }
          return shelf.Response.notFound('Not found');
        }

        final serverInstance = await shelf_io.serve(handler, 'localhost', 0);
        final serverUrl = 'http://localhost:${serverInstance.port}';

        // Publish events with various contexts
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@example.com',
          name: 'User 1',
          context: {'userId': 'user-1', 'tenantId': 'tenant-a'},
        );
        final event2 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user2@example.com',
          name: 'User 2',
          context: {'userId': 'user-2', 'tenantId': 'tenant-b'},
        );
        final event3 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 50,
          productId: 'product-1',
          context: {'userId': 'user-1', 'tenantId': 'tenant-a'},
        );
        final event4 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 75,
          productId: 'product-2',
          context: {'userId': 'user-3', 'tenantId': 'tenant-c'},
        );
        final event5 = PaymentProcessedEvent(
          aggregateId: UuidValue.generate(),
          orderId: 'order-1',
          amount: 50,
          status: 'completed',
          context: {'userId': 'user-2', 'tenantId': 'tenant-b'},
        );

        server.publish(event1);
        server.publish(event2);
        server.publish(event3);
        server.publish(event4);
        server.publish(event5);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Request events without any authorization headers
        final response = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
        );

        // Assert: Should receive ALL events
        expect(response.statusCode, equals(200));
        final events = jsonDecode(response.body) as List;
        expect(events, hasLength(5));

        // Verify we have events from different users and tenants
        final userIds = events.map((e) => e['userId']).toSet();
        final tenantIds = events.map((e) => e['tenantId']).toSet();
        expect(userIds, hasLength(3)); // user-1, user-2, user-3
        expect(tenantIds, hasLength(3)); // tenant-a, tenant-b, tenant-c

        // Cleanup
        await serverInstance.close(force: true);
      },
    );

    test(
      'complex authorization filter with multiple conditions',
      () async {
        // Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3
        // Arrange: Create complex authorization filter
        // Allow events if: (userId matches OR tenantId matches) AND sessionId matches
        bool complexAuthFilter(StoredEvent event, shelf.Request request) {
          final requestUserId = request.headers['x-user-id'];
          final requestTenantId = request.headers['x-tenant-id'];
          final requestSessionId = request.headers['x-session-id'];

          final userMatch = event.userId == requestUserId;
          final tenantMatch = event.tenantId == requestTenantId;
          final sessionMatch = event.sessionId == requestSessionId;

          return (userMatch || tenantMatch) && sessionMatch;
        }

        final endpoints = EventHttpEndpoints<StoredEvent>(
          eventRepository: repository,
          authorizationFilter: complexAuthFilter,
        );

        Future<shelf.Response> handler(shelf.Request request) async {
          if (request.method == 'GET' && request.url.path == 'events') {
            return endpoints.handleGetEvents(request);
          }
          return shelf.Response.notFound('Not found');
        }

        final serverInstance = await shelf_io.serve(handler, 'localhost', 0);
        final serverUrl = 'http://localhost:${serverInstance.port}';

        // Publish events with various combinations
        final event1 = UserCreatedEvent(
          aggregateId: UuidValue.generate(),
          email: 'user1@example.com',
          name: 'User 1',
          context: {
            'userId': 'user-1',
            'tenantId': 'tenant-a',
            'sessionId': 'session-x',
          },
        );
        final event2 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 50,
          productId: 'product-1',
          context: {
            'userId': 'user-2',
            'tenantId': 'tenant-a',
            'sessionId': 'session-x',
          },
        );
        final event3 = OrderPlacedEvent(
          aggregateId: UuidValue.generate(),
          amount: 75,
          productId: 'product-2',
          context: {
            'userId': 'user-1',
            'tenantId': 'tenant-b',
            'sessionId': 'session-y',
          },
        );
        final event4 = PaymentProcessedEvent(
          aggregateId: UuidValue.generate(),
          orderId: 'order-1',
          amount: 50,
          status: 'completed',
          context: {
            'userId': 'user-3',
            'tenantId': 'tenant-c',
            'sessionId': 'session-x',
          },
        );

        server.publish(event1);
        server.publish(event2);
        server.publish(event3);
        server.publish(event4);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act: Request events with user-1, tenant-a, session-x
        final response = await httpClient.get(
          Uri.parse('$serverUrl/events').replace(
            queryParameters: {
              'since': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
            },
          ),
          headers: {
            'x-user-id': 'user-1',
            'x-tenant-id': 'tenant-a',
            'x-session-id': 'session-x',
          },
        );

        // Assert: Should receive events 1 and 2
        // event1: userId matches AND sessionId matches ✓
        // event2: tenantId matches AND sessionId matches ✓
        // event3: userId matches BUT sessionId doesn't match ✗
        // event4: neither userId nor tenantId match ✗
        expect(response.statusCode, equals(200));
        final events = jsonDecode(response.body) as List;
        expect(events, hasLength(2));
        expect(events[0]['userId'], equals('user-1'));
        expect(events[1]['tenantId'], equals('tenant-a'));

        // Cleanup
        await serverInstance.close(force: true);
      },
    );
  });
}
