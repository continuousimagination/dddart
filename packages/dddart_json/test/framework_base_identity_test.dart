import 'dart:convert';

import 'package:dddart/dddart.dart' as dddart;
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'framework_base_identity_test.g.dart';

abstract class Value extends dddart.Value {
  const Value({required this.applicationBaseState});

  final String applicationBaseState;
}

@Serializable(fieldRename: FieldRename.snake)
class SameNamedBoundaryValue extends Value {
  const SameNamedBoundaryValue({
    required super.applicationBaseState,
    required this.childState,
  });

  final String childState;

  @override
  List<Object?> get props => [applicationBaseState, childState];
}

void main() {
  test('same-named application classes are not framework boundaries', () {
    const original = SameNamedBoundaryValue(
      applicationBaseState: 'inherited',
      childState: 'concrete',
    );
    final serializer = SameNamedBoundaryValueJsonSerializer();

    final json = serializer.toJson(original);

    expect(json, {
      'application_base_state': 'inherited',
      'child_state': 'concrete',
    });
    expect(serializer.deserialize(jsonEncode(json)), original);
  });
}
