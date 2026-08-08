import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'inherited_state_test.g.dart';

abstract class AggregateStateBase extends AggregateRoot {
  AggregateStateBase({
    required this.aggregateBaseName,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  final String aggregateBaseName;
}

abstract class AggregateStateMiddle extends AggregateStateBase {
  AggregateStateMiddle({
    required super.aggregateBaseName,
    required this.aggregateMiddleName,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  final String aggregateMiddleName;
}

@Serializable(fieldRename: FieldRename.snake)
class InheritedStateAggregate extends AggregateStateMiddle {
  InheritedStateAggregate({
    required super.aggregateBaseName,
    required super.aggregateMiddleName,
    required this.aggregateChildName,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  final String aggregateChildName;
}

abstract class EntityStateBase extends Entity {
  EntityStateBase({
    required this.entityBaseName,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  final String entityBaseName;
}

@Serializable(fieldRename: FieldRename.kebab)
class InheritedStateEntity extends EntityStateBase {
  InheritedStateEntity({
    required super.entityBaseName,
    required this.entityChildName,
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });

  final String entityChildName;
}

abstract class ValueStateBase extends Value {
  const ValueStateBase({required this.valueBaseName});

  final String valueBaseName;
}

@Serializable(fieldRename: FieldRename.snake)
class InheritedStateValue extends ValueStateBase {
  const InheritedStateValue({
    required super.valueBaseName,
    required this.valueChildName,
  });

  final String valueChildName;

  @override
  List<Object?> get props => [valueBaseName, valueChildName];
}

void main() {
  group('inherited application state', () {
    test('round-trips an aggregate across an indirect superclass chain', () {
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
      final createdAt = DateTime.utc(2025, 1, 2, 3, 4, 5);
      final updatedAt = DateTime.utc(2025, 6, 7, 8, 9, 10);
      final original = InheritedStateAggregate(
        aggregateBaseName: 'base',
        aggregateMiddleName: 'middle',
        aggregateChildName: 'child',
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final serializer = InheritedStateAggregateJsonSerializer();

      final json = serializer.toJson(original);

      expect(json, {
        'id': id.toString(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'aggregate_base_name': 'base',
        'aggregate_middle_name': 'middle',
        'aggregate_child_name': 'child',
      });
      expect(json, isNot(contains('aggregateBaseName')));

      final restored = serializer.deserialize(jsonEncode(json));
      expect(restored.aggregateBaseName, original.aggregateBaseName);
      expect(restored.aggregateMiddleName, original.aggregateMiddleName);
      expect(restored.aggregateChildName, original.aggregateChildName);
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('round-trips indirect entity lifecycle and application fields', () {
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000002');
      final createdAt = DateTime.utc(2024, 2, 3, 4, 5, 6);
      final updatedAt = DateTime.utc(2024, 7, 8, 9, 10, 11);
      final original = InheritedStateEntity(
        entityBaseName: 'base',
        entityChildName: 'child',
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final serializer = InheritedStateEntityJsonSerializer();

      final json = serializer.toJson(original);

      expect(json, {
        'id': id.toString(),
        'created-at': createdAt.toIso8601String(),
        'updated-at': updatedAt.toIso8601String(),
        'entity-base-name': 'base',
        'entity-child-name': 'child',
      });
      expect(json, isNot(contains('entityBaseName')));

      final restored = serializer.deserialize(jsonEncode(json));
      expect(restored.entityBaseName, original.entityBaseName);
      expect(restored.entityChildName, original.entityChildName);
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('round-trips inherited value state with concrete configuration', () {
      const original = InheritedStateValue(
        valueBaseName: 'base',
        valueChildName: 'child',
      );
      final serializer = InheritedStateValueJsonSerializer();

      final json = serializer.toJson(original);

      expect(json, {
        'value_base_name': 'base',
        'value_child_name': 'child',
      });
      expect(json, isNot(contains('valueBaseName')));

      final restored = serializer.deserialize(jsonEncode(json));
      expect(restored, original);
      expect(restored.valueBaseName, original.valueBaseName);
      expect(restored.valueChildName, original.valueChildName);
    });
  });
}
