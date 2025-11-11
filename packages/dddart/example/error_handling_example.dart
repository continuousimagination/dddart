import 'dart:async';
import 'package:dddart/dddart.dart';

/// Example demonstrating error handling patterns in event-driven systems.
///
/// This shows how to:
/// - Handle errors in event handlers gracefully
/// - Implement compensation events for failures
/// - Use onError callbacks for stream error handling
/// - Prevent cascading failures
/// - Log errors without crashing the system
///
/// Run with: dart run example/error_handling_example.dart
void main() async {
  print('🚨 Event Handler Error Handling Example\n');

  await _basicErrorHandling();
  await _compensationEvents();
  await _multipleHandlersWithErrors();
  await _streamErrorHandling();

  print('\n✅ All error handling examples completed!');
}

/// Demonstrate basic error handling in event handlers
Future<void> _basicErrorHandling() async {
  print('🛡️  Basic Error Handling');
  print('=' * 40);

  final eventBus = EventBus();
  final logger = SimpleLogger();

  // Handler that might fail
  eventBus.on<OrderPlacedEvent>().listen((event) async {
    try {
      print('📦 Processing order ${event.aggregateId}...');

      // Simulate a service that might fail
      await _reserveInventory(event.aggregateId, event.itemCount);

      print('✅ Inventory reserved successfully');
    } catch (e) {
      // Log error but don't crash
      logger.error(
          'Failed to reserve inventory for order ${event.aggregateId}', e);
      print('❌ Inventory reservation failed: $e');
      // System continues running despite the error
    }
  });

  // Publish an event that will cause an error
  final orderId = UuidValue.generate();
  eventBus.publish(OrderPlacedEvent(
    orderId: orderId,
    customerId: 'customer-123',
    totalAmount: 299.99,
    currency: 'USD',
    itemCount: 100, // Too many items - will fail
  ));

  await Future.delayed(Duration(milliseconds: 100));

  print('\n✅ System continued running despite error!\n');

  await eventBus.close();
}

/// Demonstrate compensation events for handling failures
Future<void> _compensationEvents() async {
  print('🔄 Compensation Events Pattern');
  print('=' * 40);

  final eventBus = EventBus();
  final logger = SimpleLogger();

  // Primary event handler with compensation
  eventBus.on<OrderPlacedEvent>().listen((event) async {
    try {
      print('📦 Processing order ${event.aggregateId}...');
      await _reserveInventory(event.aggregateId, event.itemCount);
      print('✅ Inventory reserved');
    } catch (e) {
      logger.error('Inventory reservation failed', e);

      // Publish compensation event
      print('🔄 Publishing compensation event...');
      eventBus.publish(InventoryReservationFailedEvent(
        orderId: event.aggregateId,
        reason: e.toString(),
        originalEvent: event,
      ));
    }
  });

  // Compensation event handler
  eventBus.on<InventoryReservationFailedEvent>().listen((event) {
    print('⚠️  Handling inventory reservation failure...');
    print('   Order ID: ${event.orderId}');
    print('   Reason: ${event.reason}');
    print('   → Notifying customer service');
    print('   → Updating order status to "pending_inventory"');
    print('   → Sending notification to warehouse team');
  });

  // Publish event that will fail
  final orderId = UuidValue.generate();
  eventBus.publish(OrderPlacedEvent(
    orderId: orderId,
    customerId: 'customer-456',
    totalAmount: 499.99,
    currency: 'USD',
    itemCount: 200, // Will fail
  ));

  await Future.delayed(Duration(milliseconds: 100));

  print('\n✅ Compensation event handled gracefully!\n');

  await eventBus.close();
}

/// Demonstrate error isolation with multiple handlers
Future<void> _multipleHandlersWithErrors() async {
  print('🔀 Error Isolation with Multiple Handlers');
  print('=' * 40);

  final eventBus = EventBus();
  final logger = SimpleLogger();

  // Handler 1: Email service (will succeed)
  eventBus.on<OrderPlacedEvent>().listen((event) async {
    try {
      print('📧 Email Service: Sending confirmation...');
      await _sendEmail(event.customerId);
      print('✅ Email sent successfully');
    } catch (e) {
      logger.error('Email service failed', e);
      print('❌ Email failed: $e');
    }
  });

  // Handler 2: Inventory service (will fail)
  eventBus.on<OrderPlacedEvent>().listen((event) async {
    try {
      print('📦 Inventory Service: Reserving items...');
      await _reserveInventory(event.aggregateId, event.itemCount);
      print('✅ Inventory reserved');
    } catch (e) {
      logger.error('Inventory service failed', e);
      print('❌ Inventory failed: $e');
    }
  });

  // Handler 3: Analytics service (will succeed)
  eventBus.on<OrderPlacedEvent>().listen((event) async {
    try {
      print('📊 Analytics Service: Recording order...');
      await _recordAnalytics(event.totalAmount);
      print('✅ Analytics recorded');
    } catch (e) {
      logger.error('Analytics service failed', e);
      print('❌ Analytics failed: $e');
    }
  });

  // Publish event
  final orderId = UuidValue.generate();
  eventBus.publish(OrderPlacedEvent(
    orderId: orderId,
    customerId: 'customer-789',
    totalAmount: 199.99,
    currency: 'USD',
    itemCount: 150, // Will cause inventory to fail
  ));

  await Future.delayed(Duration(milliseconds: 100));

  print('\n✅ Other handlers continued despite one failure!\n');

  await eventBus.close();
}

/// Demonstrate stream-level error handling
Future<void> _streamErrorHandling() async {
  print('🌊 Stream-Level Error Handling');
  print('=' * 40);

  final eventBus = EventBus();
  final logger = SimpleLogger();

  // Handler with onError callback
  final subscription = eventBus.on<OrderPlacedEvent>().listen(
    (event) async {
      try {
        print('📦 Processing order ${event.aggregateId}...');

        // Simulate an error
        if (event.itemCount > 50) {
          throw Exception('Critical inventory error: Too many items');
        }

        print('✅ Order processed successfully');
      } catch (e) {
        // Catch and log the error
        logger.error('Order processing error', e);
        print('⚠️  Error caught in handler:');
        print('   Error: $e');
        print('   → Logging to error tracking service');
        print('   → Alerting on-call engineer');
        print('   → Handler continues running');
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      // Stream-level error handler (for uncaught errors)
      logger.error('Stream error caught', error);
      print('⚠️  Stream error handler invoked:');
      print('   Error: $error');
      print('   → This catches errors that escape try-catch');
    },
  );

  // Publish events
  print('Publishing event 1 (will succeed)...');
  eventBus.publish(OrderPlacedEvent(
    orderId: UuidValue.generate(),
    customerId: 'customer-001',
    totalAmount: 99.99,
    currency: 'USD',
    itemCount: 10,
  ));

  await Future.delayed(Duration(milliseconds: 50));

  print('\nPublishing event 2 (will fail)...');
  eventBus.publish(OrderPlacedEvent(
    orderId: UuidValue.generate(),
    customerId: 'customer-002',
    totalAmount: 999.99,
    currency: 'USD',
    itemCount: 100, // Will trigger error
  ));

  await Future.delayed(Duration(milliseconds: 50));

  print('\nPublishing event 3 (will succeed)...');
  eventBus.publish(OrderPlacedEvent(
    orderId: UuidValue.generate(),
    customerId: 'customer-003',
    totalAmount: 49.99,
    currency: 'USD',
    itemCount: 5,
  ));

  await Future.delayed(Duration(milliseconds: 50));

  print('\n✅ Stream continued processing after error!\n');

  await subscription.cancel();
  await eventBus.close();
}

// Simulated services that can fail

Future<void> _reserveInventory(UuidValue orderId, int itemCount) async {
  await Future.delayed(Duration(milliseconds: 10));

  if (itemCount > 50) {
    throw Exception(
        'Insufficient inventory: requested $itemCount, available 50');
  }
}

Future<void> _sendEmail(String customerId) async {
  await Future.delayed(Duration(milliseconds: 10));
  // Email service always succeeds in this example
}

Future<void> _recordAnalytics(double amount) async {
  await Future.delayed(Duration(milliseconds: 10));
  // Analytics service always succeeds in this example
}

// Simple logger for demonstration
class SimpleLogger {
  void error(String message, Object error) {
    // In production, this would log to a proper logging service
    // For now, we just track that errors were logged
  }
}

// Example events

class OrderPlacedEvent extends DomainEvent {
  final String customerId;
  final double totalAmount;
  final String currency;
  final int itemCount;

  OrderPlacedEvent({
    required UuidValue orderId,
    required this.customerId,
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
  }) : super(
          aggregateId: orderId,
          context: {
            'customerId': customerId,
            'totalAmount': totalAmount,
          },
        );
}

class InventoryReservationFailedEvent extends DomainEvent {
  final UuidValue orderId;
  final String reason;
  final OrderPlacedEvent originalEvent;

  InventoryReservationFailedEvent({
    required this.orderId,
    required this.reason,
    required this.originalEvent,
  }) : super(
          aggregateId: orderId,
          context: {
            'reason': reason,
            'customerId': originalEvent.customerId,
          },
        );
}
