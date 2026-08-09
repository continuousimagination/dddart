import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'annotation_configuration_precedence_test.g.dart';

@Serializable()
class FrameworkDefaultValue extends Value {
  const FrameworkDefaultValue({
    required this.displayName,
    this.optionalNote,
  });

  final String displayName;
  final String? optionalNote;

  @override
  List<Object?> get props => [displayName, optionalNote];
}

@Serializable(
  fieldRename: FieldRename.snake,
  includeNullFields: true,
)
class AncestorConfiguredValue extends Value {
  const AncestorConfiguredValue();

  @override
  List<Object?> get props => const [];
}

@Serializable(fieldRename: FieldRename.kebab)
class ConfiguredValue extends AncestorConfiguredValue {
  const ConfiguredValue({
    required this.displayName,
    this.optionalNote,
  });

  final String displayName;
  final String? optionalNote;

  @override
  List<Object?> get props => [displayName, optionalNote];
}

void main() {
  const value = ConfiguredValue(displayName: 'annotation');

  group('generated configuration precedence', () {
    test('framework defaults apply below a default concrete annotation', () {
      const frameworkValue = FrameworkDefaultValue(displayName: 'framework');
      final serializer = FrameworkDefaultValueJsonSerializer();

      final json = serializer.toJson(frameworkValue);

      expect(json, {'displayName': 'framework'});
      expect(
        serializer.fromJson({'displayName': 'restored'}),
        const FrameworkDefaultValue(displayName: 'restored'),
      );

      final encoded = serializer.serialize(frameworkValue);
      expect(jsonDecode(encoded), {'displayName': 'framework'});
      expect(
        serializer.deserialize('{"displayName":"decoded"}'),
        const FrameworkDefaultValue(displayName: 'decoded'),
      );
    });

    test(
        'concrete annotation overrides framework defaults without merging '
        'ancestor annotation settings', () {
      final serializer = ConfiguredValueJsonSerializer();

      final json = serializer.toJson(value);

      expect(json, {'display-name': 'annotation'});
      expect(json, isNot(contains('display_name')));
      expect(json, isNot(contains('optional-note')));
      expect(
        serializer.fromJson({'display-name': 'restored'}),
        const ConfiguredValue(displayName: 'restored'),
      );

      final encoded = ConfiguredValueJsonSerializer.encode(value);
      expect(encoded, {'display-name': 'annotation'});
      expect(
        ConfiguredValueJsonSerializer.decode({'display-name': 'decoded'}),
        const ConfiguredValue(displayName: 'decoded'),
      );
    });

    test('serializer constructor configuration overrides concrete annotation',
        () {
      const constructorConfig = SerializationConfig(
        fieldRename: FieldRename.snake,
        includeNullFields: true,
      );
      final serializer = ConfiguredValueJsonSerializer(constructorConfig);

      final json = serializer.toJson(value);

      expect(
        json,
        {'display_name': 'annotation', 'optional_note': null},
      );
      expect(
        serializer.fromJson({
          'display_name': 'restored',
          'optional_note': null,
        }),
        const ConfiguredValue(displayName: 'restored'),
      );

      final encoded = serializer.serialize(value);
      expect(
        jsonDecode(encoded),
        {'display_name': 'annotation', 'optional_note': null},
      );
      expect(
        serializer.deserialize(
          '{"display_name":"decoded","optional_note":null}',
        ),
        const ConfiguredValue(displayName: 'decoded'),
      );
    });

    test('operation configuration overrides serializer constructor', () {
      const constructorConfig = SerializationConfig(
        fieldRename: FieldRename.snake,
        includeNullFields: true,
      );
      const operationConfig = SerializationConfig();
      final serializer = ConfiguredValueJsonSerializer(constructorConfig);

      final json = serializer.toJson(value, operationConfig);

      expect(json, {'displayName': 'annotation'});
      expect(
        serializer.fromJson(
          {'displayName': 'restored'},
          operationConfig,
        ),
        const ConfiguredValue(displayName: 'restored'),
      );

      final encoded = serializer.serialize(value, operationConfig);
      expect(jsonDecode(encoded), {'displayName': 'annotation'});
      expect(
        serializer.deserialize(
          '{"displayName":"decoded"}',
          operationConfig,
        ),
        const ConfiguredValue(displayName: 'decoded'),
      );
    });
  });
}
