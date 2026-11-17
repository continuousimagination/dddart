import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

part 'serializer_contract_test.g.dart';

class ContractId extends Identity {
  const ContractId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

const encodingFailure = SerializationException('typed encoding failure');
const decodingFailure = DeserializationException('typed decoding failure');
final applicationBug = StateError('application bug');

class ContractCodec implements IdentityCodec<ContractId> {
  @override
  Object toJson(ContractId id) {
    switch (id.value) {
      case 'format':
        throw const FormatException('bad identity');
      case 'typed':
        throw encodingFailure;
      case 'bug':
        throw applicationBug;
      case 'unencodable':
        return DateTime.utc(2026);
      default:
        return id.value;
    }
  }

  @override
  ContractId fromJson(Object? value) {
    if (value == 'typed') throw decodingFailure;
    if (value == 'bug') throw applicationBug;
    if (value is! String) {
      throw const FormatException('expected string identity');
    }
    return ContractId(value);
  }

  @override
  String toKey(ContractId id) => id.value;
  @override
  ContractId fromKey(String value) => ContractId(value);
}

@Serializable(fieldRename: FieldRename.snake)
class ContractValue extends Value {
  ContractValue({
    required this.identity,
    required this.displayName,
    this.note,
  }) {
    if (displayName == 'bug') throw applicationBug;
  }
  final ContractId identity;
  final String displayName;
  final String? note;
  @override
  List<Object?> get props => [identity, displayName, note];
}

class HandwrittenSerializer extends JsonSerializer<ContractValue> {
  HandwrittenSerializer(
    this.codecs, [
    this.defaults = const SerializationConfig(fieldRename: FieldRename.snake),
  ]);
  final IdentityCodecRegistry codecs;
  final SerializationConfig defaults;

  @override
  Map<String, dynamic> toJson(
    ContractValue value, [
    SerializationConfig? config,
  ]) {
    final effective = config ?? defaults;
    return JsonSerializer.encodeValue(
      () => {
        'identity': codecs.toJson(value.identity),
        SerializationUtils.applyFieldRename(
          'displayName',
          effective.fieldRename,
        ): value.displayName,
        if (value.note != null || effective.includeNullFields)
          'note': value.note,
      },
      expectedType: 'ContractValue',
    );
  }

  @override
  ContractValue fromJson(dynamic json, [SerializationConfig? config]) {
    if (json is! Map<String, dynamic>) {
      throw const DeserializationException(
        'Expected object',
        expectedType: 'ContractValue',
      );
    }
    final effective = config ?? defaults;
    return ContractValue(
      identity: JsonSerializer.readValue(
        () => codecs.fromJson<ContractId>(json['identity']),
        expectedType: 'ContractValue',
        field: 'identity',
      ),
      displayName: JsonSerializer.readValue(
        () => json[SerializationUtils.applyFieldRename(
          'displayName',
          effective.fieldRename,
        )] as String,
        expectedType: 'ContractValue',
        field: 'displayName',
      ),
      note: JsonSerializer.readValue(
        () => json['note'] as String?,
        expectedType: 'ContractValue',
        field: 'note',
      ),
    );
  }
}

void main() {
  final codecs = IdentityCodecRegistry()
    ..register<ContractId>('contract', ContractCodec());
  final value =
      ContractValue(identity: const ContractId('native'), displayName: 'name');
  final generated = ContractValueJsonSerializer.withIdentityCodecs(codecs);
  final handwritten = HandwrittenSerializer(codecs);
  for (final entry
      in {'generated': generated, 'handwritten': handwritten}.entries) {
    final serializer = entry.value;
    group(entry.key, () {
      test('typed identity and full per-call configuration override round trip',
          () {
        const config = SerializationConfig(
          fieldRename: FieldRename.kebab,
          includeNullFields: true,
        );
        expect(
          serializer.toJson(value),
          {'identity': 'native', 'display_name': 'name'},
        );
        final json = serializer.toJson(value, config);
        expect(
          json,
          {'identity': 'native', 'display-name': 'name', 'note': null},
        );
        expect(serializer.fromJson(json, config), value);
        expect(
          serializer.deserialize(serializer.serialize(value, config), config),
          value,
        );
      });
      test('malformed JSON retains cause and stack; non-object JSON is typed',
          () {
        expect(
          () => serializer.deserialize('{'),
          throwsA(
            isA<DeserializationException>()
                .having((e) => e.cause, 'cause', isA<FormatException>())
                .having((e) => e.stackTrace, 'stack', isNotNull),
          ),
        );
        for (final input in ['[]', '1', 'null', '"string"']) {
          expect(
            () => serializer.deserialize(input),
            throwsA(isA<DeserializationException>()),
          );
        }
      });
      test('missing, invalid and malformed codec input are normalized', () {
        for (final json in <Map<String, dynamic>>[
          {},
          {'display_name': 42, 'identity': 'native'},
          {'display_name': 'name', 'identity': 42},
        ]) {
          expect(
            () => serializer.fromJson(json),
            throwsA(
              isA<DeserializationException>()
                  .having((e) => e.cause, 'cause', isNotNull)
                  .having((e) => e.stackTrace, 'stack', isNotNull),
            ),
          );
        }
      });
      test('codec validation and unencodable string output retain their cause',
          () {
        expect(
          () => serializer.toJson(
            ContractValue(
              identity: const ContractId('format'),
              displayName: 'name',
            ),
          ),
          throwsA(
            isA<SerializationException>()
                .having((e) => e.cause, 'cause', isA<FormatException>()),
          ),
        );
        expect(
          () => serializer.serialize(
            ContractValue(
              identity: const ContractId('unencodable'),
              displayName: 'name',
            ),
          ),
          throwsA(
            isA<SerializationException>().having(
              (e) => e.cause,
              'cause',
              isA<JsonUnsupportedObjectError>(),
            ),
          ),
        );
      });
      test('already typed failures keep object identity', () {
        expect(
          () => serializer.serialize(
            ContractValue(
              identity: const ContractId('typed'),
              displayName: 'name',
            ),
          ),
          throwsA(same(encodingFailure)),
        );
        expect(
          () => serializer
              .deserialize('{"identity":"typed","display_name":"name"}'),
          throwsA(same(decodingFailure)),
        );
      });
      test('codec and application constructor bugs are not relabeled', () {
        expect(
          () => serializer.serialize(
            ContractValue(
              identity: const ContractId('bug'),
              displayName: 'name',
            ),
          ),
          throwsA(same(applicationBug)),
        );
        expect(
          () => serializer
              .deserialize('{"identity":"bug","display_name":"name"}'),
          throwsA(same(applicationBug)),
        );
        expect(
          () => serializer
              .deserialize('{"identity":"native","display_name":"bug"}'),
          throwsA(same(applicationBug)),
        );
      });
      test('wrong config through dynamic dispatch fails at the typed boundary',
          () {
        final dynamic receiver = serializer;
        expect(
          () => receiver.serialize(value, Object()),
          throwsA(isA<TypeError>()),
        );
        expect(
          () => receiver.toJson(value, Object()),
          throwsA(isA<TypeError>()),
        );
      });
    });
  }
  test('static generated convenience methods share map behavior and codecs',
      () {
    expect(
      ContractValueJsonSerializer.decode(
        ContractValueJsonSerializer.encode(value, null, codecs),
        null,
        codecs,
      ),
      value,
    );
    expect(
      () => ContractValueJsonSerializer.decode(
        {'identity': 'typed', 'display_name': 'name'},
        null,
        codecs,
      ),
      throwsA(same(decodingFailure)),
    );
  });
}
