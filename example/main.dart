import 'lib/example.dart';

/// Entry point for the DDDart serialization example.
/// 
/// This example demonstrates:
/// - Basic serialization and deserialization
/// - Field naming strategies (camelCase, snake_case, kebab-case)
/// - Constructor configuration with method overrides
/// - Complex object graph serialization
/// - Error handling scenarios
/// - Performance characteristics
/// 
/// Run with: dart run example/main.dart
void main() {
  final example = SerializationExample();
  example.runAll();
}