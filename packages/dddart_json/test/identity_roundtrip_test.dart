import 'dart:convert';

import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'test_models.dart';

class _NativeCodec implements IdentityCodec<TestNativeIdentity> {
  const _NativeCodec();
  @override
  String toJson(TestNativeIdentity identity) => identity.value;
  @override
  TestNativeIdentity fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('Expected native identity');
    }
    return TestNativeIdentity(value);
  }

  @override
  String toKey(TestNativeIdentity identity) => identity.value;
  @override
  TestNativeIdentity fromKey(String value) => TestNativeIdentity(value);
}

class _ScopedCodec implements IdentityCodec<TestScopedIdentity> {
  const _ScopedCodec();
  @override
  Map<String, Object?> toJson(TestScopedIdentity identity) =>
      {'repository': identity.repository, 'number': identity.number};
  @override
  TestScopedIdentity fromJson(Object? value) {
    if (value is! Map ||
        value['repository'] is! String ||
        value['number'] is! int) {
      throw const FormatException('Expected scoped identity');
    }
    return TestScopedIdentity(
      value['repository'] as String,
      value['number'] as int,
    );
  }

  @override
  String toKey(TestScopedIdentity identity) =>
      jsonEncode([identity.repository, identity.number]);
  @override
  TestScopedIdentity fromKey(String value) {
    final tuple = jsonDecode(value) as List<dynamic>;
    if (tuple.length != 2) throw const FormatException('Expected scoped tuple');
    return fromJson({'repository': tuple[0], 'number': tuple[1]});
  }
}

void main() {
  IdentityCodecRegistry registry() => IdentityCodecRegistry()
    ..register<TestNativeIdentity>('native.v1', const _NativeCodec())
    ..register<TestScopedIdentity>('scoped.v1', const _ScopedCodec());

  TestNativeIdentityAggregate native() => TestNativeIdentityAggregate(
        id: const TestNativeIdentity('GitHub/native%, café'),
        reference: const TestNativeIdentity('reference'),
        child: const TestIdentityHolder(
          identity: TestNativeIdentity('nested child'),
        ),
        optionalIdentity: const TestNativeIdentity('optional'),
        history: const [
          TestNativeIdentity('first'),
          null,
          TestNativeIdentity('a,b'),
        ],
        identities: {
          const TestNativeIdentity('IssueA'),
          const TestNativeIdentity('issuea'),
        },
        byName: const {
          'present': TestNativeIdentity('map value'),
          'null': null,
        },
        byIdentity: {const TestNativeIdentity('key/%, café'): 'value'},
        nested: const [
          [TestNativeIdentity('matrix'), null],
        ],
        createdAt: DateTime.utc(2026, 10, 28),
        updatedAt: DateTime.utc(2026, 10, 28),
      );

  test('generated serializer preserves identity throughout nested collections',
      () {
    final original = native();
    final codecs = registry();
    final serializer =
        TestNativeIdentityAggregateJsonSerializer.withIdentityCodecs(
      codecs,
    );
    expect(identical(serializer.identityCodecs, codecs), isTrue);
    final json = serializer.toJson(original);
    expect(json['id'], original.id.value);
    expect(json['reference'], 'reference');
    expect(json['child'], {'identity': 'nested child'});
    expect(json['history'], ['first', null, 'a,b']);
    expect(json['byIdentity'], {'key/%, café': 'value'});
    expect(json['nested'], [
      ['matrix', null],
    ]);
    final restored = serializer.deserialize(serializer.serialize(original));
    expect(restored.id, original.id);
    expect(restored.reference, original.reference);
    expect(restored.child, original.child);
    expect(restored.optionalIdentity, original.optionalIdentity);
    expect(restored.history, original.history);
    expect(restored.identities, original.identities);
    expect(restored.byName, original.byName);
    expect(restored.byIdentity, original.byIdentity);
    expect(restored.nested, original.nested);
    expect(restored.createdAt, original.createdAt);
    expect(restored.updatedAt, original.updatedAt);
  });

  test('custom codecs propagate with field renaming and nullable values', () {
    final codecs = registry();
    final serializer =
        TestNativeIdentityAggregateJsonSerializer.withIdentityCodecs(codecs);
    const config = SerializationConfig(
      fieldRename: FieldRename.snake,
      includeNullFields: true,
    );
    final json = serializer.toJson(native(), config);
    expect(json['optional_identity'], 'optional');
    final restored = serializer.fromJson(json, config);
    expect(restored.optionalIdentity, const TestNativeIdentity('optional'));
    final nullOriginal = TestNativeIdentityAggregate(
      id: const TestNativeIdentity('native'),
      reference: const TestNativeIdentity('ref'),
      child: const TestIdentityHolder(identity: TestNativeIdentity('child')),
    );
    final nullJson = serializer.toJson(nullOriginal, config);
    expect(nullJson.containsKey('optional_identity'), isTrue);
    expect(nullJson['optional_identity'], isNull);
    expect(serializer.fromJson(nullJson, config).optionalIdentity, isNull);
    expect(
      TestNativeIdentityAggregateJsonSerializer.decode(
        TestNativeIdentityAggregateJsonSerializer.encode(
          native(),
          config,
          codecs,
        ),
        config,
        codecs,
      ).reference,
      const TestNativeIdentity('reference'),
    );
  });

  test('structured scoped IDs retain native integers and distinct scopes', () {
    final serializer =
        TestScopedIdentityAggregateJsonSerializer.withIdentityCodecs(
      registry(),
    );
    for (final repository in ['org/one', 'org/two']) {
      final original = TestScopedIdentityAggregate(
        id: TestScopedIdentity(repository, 12),
        label: repository,
      );
      final json = serializer.toJson(original);
      expect(json['id'], {'repository': repository, 'number': 12});
      final restored = serializer.deserialize(serializer.serialize(original));
      expect(restored.id, original.id);
      expect(restored.label, original.label);
    }
  });

  test('missing and malformed identity codecs fail instead of UUID coercion',
      () {
    expect(
      () => TestNativeIdentityAggregateJsonSerializer().toJson(native()),
      throwsA(isA<SerializationException>()),
    );
    final serializer =
        TestNativeIdentityAggregateJsonSerializer.withIdentityCodecs(
      registry(),
    );
    for (final badId in <Object?>[null, 12, <String, Object?>{}]) {
      final json = serializer.toJson(native())..['id'] = badId;
      expect(
        () => serializer.fromJson(json),
        throwsA(isA<DeserializationException>()),
      );
    }
    final scoped = TestScopedIdentityAggregateJsonSerializer.withIdentityCodecs(
      registry(),
    );
    final json = scoped.toJson(
      TestScopedIdentityAggregate(
        id: const TestScopedIdentity('repo', 12),
        label: 'label',
      ),
    );
    json['id'] = {'repository': 'repo', 'number': '12'};
    expect(
      () => scoped.fromJson(json),
      throwsA(isA<DeserializationException>()),
    );
  });
}
