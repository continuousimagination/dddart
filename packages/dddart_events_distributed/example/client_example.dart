/// Example demonstrating EventBusClient with HTTP polling.
///
/// This example shows how to:
/// - Set up EventBusClient with polling
/// - Configure event registry for deserialization
/// - Subscribe to events received from server
/// - Optionally forward local events to server
///
/// Run server_example.dart first before running this client.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';

import 'lib/event_registry.dart';
import 'lib/example_events.dart';

void main() async {
  print('Starting EventBusClient example...\n');

  // Create local EventBus
  final eventBus = EventBus();

  // Create EventBusClient with polling
  final client = EventBusClient(
    localEventBus: eventBus,
    serverUrl: 'http://localhost:8080',
    eventRegistry: generatedEventRegistry,
    autoForward: true, // Automatically forward local events to server
    initialTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
  );

  print('Client configured:');
  print('  Server URL: http://localhost:8080');
  print('  Polling interval: 5 seconds');
  print('  Auto-forward: enabled');
  print('  Event registry: ${generatedEventRegistry.length} event types\n');

  // Subscribe to events received from server
  client.on<UserCreatedEvent>().listen((event) {
    print('Client received UserCreatedEvent: ${event.email}');
  });

  client.on<OrderPurchasedEvent>().listen((event) {
    print('Client received OrderPurchasedEvent: \$${event.amount}');
  });

  client.on<OrderPlacedEvent>().listen((event) {
    print('Client received OrderPlacedEvent: \$${event.amount}');
  });

  client.on<PaymentProcessedEvent>().listen((event) {
    print('Client received PaymentProcessedEvent: ${event.status}');
  });

  print('Subscribed to events. Polling server every 5 seconds...\n');

  // Wait a bit for initial poll
  await Future<void>.delayed(const Duration(seconds: 6));

  // Publish a local event (will be auto-forwarded to server)
  print('\nPublishing local event (will be forwarded to server)...');
  final localEvent = OrderPlacedEvent(
    aggregateId: UuidValue.generate(),
    amount: 149.99,
    productId: 'product-789',
    context: {
      'userId': 'user-789',
      'tenantId': 'tenant-1',
    },
  );
  client.publish(localEvent);

  print('\nClient is running. Events from server will appear here.');
  print('Press Ctrl+C to stop the client.\n');

  // Keep client running
  await Future<void>.delayed(const Duration(hours: 1));

  print('\nShutting down...');
  await client.close();
  print('Client stopped.');
}
