import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'nullable_collection_elements_test.g.dart';

enum CollectionStatus { pending, complete }

@Serializable()
class CollectionValue extends Value {
  const CollectionValue({required this.label});

  final String label;

  @override
  List<Object?> get props => [label];
}

@Serializable()
class NullableElementAggregate extends AggregateRoot {
  NullableElementAggregate({
    required this.primitiveList,
    required this.dateSet,
    required this.enumList,
    required this.valueList,
    required this.primitiveMap,
    required this.dateMap,
    required this.enumMap,
    required this.valueMap,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final List<String?> primitiveList;
  final Set<DateTime?> dateSet;
  final List<CollectionStatus?> enumList;
  final List<CollectionValue?> valueList;
  final Map<String, String?> primitiveMap;
  final Map<String, DateTime?> dateMap;
  final Map<String, CollectionStatus?> enumMap;
  final Map<String, CollectionValue?> valueMap;
}

void main() {
  test('nullable collection and map elements round-trip safely', () {
    final timestamp = DateTime.utc(2026, 8, 8, 12, 30);
    const value = CollectionValue(label: 'present');
    final original = NullableElementAggregate(
      primitiveList: const ['present', null],
      dateSet: {timestamp, null},
      enumList: const [CollectionStatus.complete, null],
      valueList: const [value, null],
      primitiveMap: const {'present': 'value', 'missing': null},
      dateMap: {'present': timestamp, 'missing': null},
      enumMap: const {
        'present': CollectionStatus.pending,
        'missing': null,
      },
      valueMap: const {'present': value, 'missing': null},
    );

    final serializer = NullableElementAggregateJsonSerializer();
    final json = serializer.toJson(original);

    expect(json['primitiveList'], ['present', null]);
    expect(json['dateSet'], [timestamp.toIso8601String(), null]);
    expect(json['enumList'], ['complete', null]);
    expect(json['valueList'], [
      {'label': 'present'},
      null,
    ]);
    expect(json['primitiveMap'], {'present': 'value', 'missing': null});
    expect(
      json['dateMap'],
      {'present': timestamp.toIso8601String(), 'missing': null},
    );
    expect(json['enumMap'], {'present': 'pending', 'missing': null});
    expect(json['valueMap'], {
      'present': {'label': 'present'},
      'missing': null,
    });

    final restored = serializer.deserialize(serializer.serialize(original));

    expect(restored.primitiveList, original.primitiveList);
    expect(restored.dateSet, original.dateSet);
    expect(restored.enumList, original.enumList);
    expect(restored.valueList, original.valueList);
    expect(restored.primitiveMap, original.primitiveMap);
    expect(restored.dateMap, original.dateMap);
    expect(restored.enumMap, original.enumMap);
    expect(restored.valueMap, original.valueMap);
  });
}
