import 'lib/events_example.dart';

/// Entry point for the DDDart domain events example.
///
/// This example demonstrates:
/// - Basic event raising in aggregates
/// - EventBus publish/subscribe functionality
/// - Multiple listeners for the same event
/// - Type-filtered event subscriptions
/// - Complete event lifecycle management
/// - Real-world e-commerce workflow scenario
///
/// Run with: dart run example/events_main.dart
Future<void> main() async {
  final example = EventsExample();
  await example.runAll();
}
