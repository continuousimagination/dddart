/// Test to verify nullable DateTime field serialization with includeNullFields.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'nullable_datetime_test.g.dart';

/// Test aggregate with nullable DateTime field.
@Serializable()
class TaskAggregate extends AggregateRoot {
  TaskAggregate({
    required this.title,
    this.completedAt,
    this.dueDate,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String title;
  final DateTime? completedAt;
  final DateTime? dueDate;
}

void main() {
  group('Nullable DateTime Field Tests', () {
    test('Serializes nullable DateTime when value is present', () {
      final completedDate = DateTime(2024, 1, 15, 10, 30);
      final task = TaskAggregate(
        title: 'Complete project',
        completedAt: completedDate,
      );

      final serializer = TaskAggregateJsonSerializer();
      final json = serializer.toJson(task);

      expect(json['title'], equals('Complete project'));
      expect(json['completedAt'], equals(completedDate.toIso8601String()));
      expect(json.containsKey('dueDate'), isFalse);
    });

    test('Excludes null DateTime fields by default', () {
      final task = TaskAggregate(
        title: 'Incomplete task',
      );

      final serializer = TaskAggregateJsonSerializer();
      final json = serializer.toJson(task);

      expect(json['title'], equals('Incomplete task'));
      expect(json.containsKey('completedAt'), isFalse);
      expect(json.containsKey('dueDate'), isFalse);
    });

    test('Includes null DateTime fields when includeNullFields is true', () {
      final task = TaskAggregate(
        title: 'Task with nulls',
      );

      final serializer = TaskAggregateJsonSerializer();
      const config = SerializationConfig(includeNullFields: true);
      final json = serializer.toJson(task, config);

      expect(json['title'], equals('Task with nulls'));
      expect(json.containsKey('completedAt'), isTrue);
      expect(json['completedAt'], isNull);
      expect(json.containsKey('dueDate'), isTrue);
      expect(json['dueDate'], isNull);
    });

    test(
        'Handles mixed null and non-null DateTime fields with includeNullFields',
        () {
      final dueDate = DateTime(2024, 12, 31);
      final task = TaskAggregate(
        title: 'Mixed task',
        dueDate: dueDate,
      );

      final serializer = TaskAggregateJsonSerializer();
      const config = SerializationConfig(includeNullFields: true);
      final json = serializer.toJson(task, config);

      expect(json['title'], equals('Mixed task'));
      expect(json.containsKey('completedAt'), isTrue);
      expect(json['completedAt'], isNull);
      expect(json.containsKey('dueDate'), isTrue);
      expect(json['dueDate'], equals(dueDate.toIso8601String()));
    });

    test('Deserializes nullable DateTime fields correctly', () {
      final json = {
        'title': 'Restored task',
        'completedAt': '2024-01-15T10:30:00.000Z',
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'createdAt': '2024-01-01T12:00:00.000Z',
        'updatedAt': '2024-01-01T12:00:00.000Z',
      };

      final serializer = TaskAggregateJsonSerializer();
      final task = serializer.fromJson(json);

      expect(task.title, equals('Restored task'));
      expect(task.completedAt, isNotNull);
      expect(
        task.completedAt!.toIso8601String(),
        equals('2024-01-15T10:30:00.000Z'),
      );
      expect(task.dueDate, isNull);
    });

    test('Round-trip with nullable DateTime and includeNullFields', () {
      final original = TaskAggregate(
        title: 'Round-trip task',
        dueDate: DateTime(2024, 6),
      );

      final serializer = TaskAggregateJsonSerializer();
      const config = SerializationConfig(includeNullFields: true);

      final json = serializer.toJson(original, config);
      final restored = serializer.fromJson(json, config);

      expect(restored.title, equals(original.title));
      expect(restored.completedAt, isNull);
      expect(restored.dueDate, isNotNull);
      expect(
        restored.dueDate!.toIso8601String(),
        equals(original.dueDate!.toIso8601String()),
      );
    });
  });
}
