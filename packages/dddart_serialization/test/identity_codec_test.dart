import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

class _NativeId extends Identity {
  const _NativeId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
  @override
  String toString() => 'debug label is not a wire format';
}

class _ScopedId extends Identity {
  const _ScopedId(this.scope, this.number);
  final String scope;
  final int number;
  @override
  List<Object?> get props => [scope, number];
}

class _NativeCodec implements IdentityCodec<_NativeId> {
  const _NativeCodec();
  @override
  String toJson(_NativeId identity) => identity.value;
  @override
  _NativeId fromJson(Object? value) {
    if (value is! String) throw const FormatException('Expected native string');
    return _NativeId(value);
  }

  @override
  String toKey(_NativeId identity) => identity.value;
  @override
  _NativeId fromKey(String value) => _NativeId(value);
}

class _LossyNativeCodec extends _NativeCodec {
  const _LossyNativeCodec();
  @override
  String toKey(_NativeId identity) => identity.value.toLowerCase();
}

class _ScopedCodec implements IdentityCodec<_ScopedId> {
  const _ScopedCodec();
  @override
  Map<String, Object?> toJson(_ScopedId identity) =>
      {'scope': identity.scope, 'number': identity.number};
  @override
  _ScopedId fromJson(Object? value) {
    if (value is! Map || value['scope'] is! String || value['number'] is! int) {
      throw const FormatException('Expected scoped identity');
    }
    return _ScopedId(value['scope'] as String, value['number'] as int);
  }

  @override
  String toKey(_ScopedId identity) =>
      jsonEncode([identity.scope, identity.number]);
  @override
  _ScopedId fromKey(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.length != 2) {
      throw const FormatException('Expected tuple');
    }
    return fromJson({'scope': decoded[0], 'number': decoded[1]});
  }
}

void main() {
  IdentityCodecRegistry registry() => IdentityCodecRegistry()
    ..register<_NativeId>('native.v1', const _NativeCodec())
    ..register<_ScopedId>('scoped.v1', const _ScopedCodec());

  test('UUID codec retains validation and string round-trips', () {
    final codecs = IdentityCodecRegistry();
    final id = UuidValue.generate();
    expect(codecs.toJson(id), id.uuid);
    expect(codecs.fromJson<UuidValue>(id.uuid), id);
    expect(codecs.toKey(id), id.uuid);
    expect(codecs.fromKey<UuidValue>(id.uuid), id);
    expect(
      () => codecs.fromJson<UuidValue>('not-uuid'),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => codecs.fromKey<UuidValue>('not-uuid'),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => codecs.fromJson<UuidValue>(42),
      throwsA(isA<DeserializationException>()),
    );
  });

  test('native identity uses its explicit codec rather than toString', () {
    final codecs = registry();
    const id = _NativeId('IssueA/%, café');
    expect(codecs.toJson(id), id.value);
    expect(codecs.fromJson<_NativeId>(id.value), id);
    expect(codecs.toKey(id), id.value);
    expect(codecs.fromKey<_NativeId>(id.value), id);
    expect(
      codecs.toKey(const _NativeId('IssueA')),
      isNot(codecs.toKey(const _NativeId('issuea'))),
    );
  });

  test('scoped identity preserves structural values and unambiguous keys', () {
    final codecs = registry();
    const first = _ScopedId('org/repo, [one]', 12);
    const second = _ScopedId('org/repo, [two]', 12);
    final json = codecs.toJson(first);
    expect(json, {'scope': first.scope, 'number': 12});
    expect(codecs.fromJson<_ScopedId>(json), first);
    expect(codecs.fromKey<_ScopedId>(codecs.toKey(first)), first);
    expect(codecs.toKey(first), isNot(codecs.toKey(second)));
    expect(
      () => codecs.fromJson<_ScopedId>({'scope': 'x', 'number': '12'}),
      throwsA(isA<DeserializationException>()),
    );
  });

  test('tagged stream uses registered keys and restores every concrete kind',
      () {
    final codecs = registry();
    final values = <Identity>[
      const _NativeId('12'),
      const _ScopedId('repo', 12),
      UuidValue.generate(),
    ];
    final encoded = values.map(codecs.toTaggedJson).toList();
    expect(
      encoded.map((value) => value['type']),
      ['native.v1', 'scoped.v1', 'uuid'],
    );
    expect(encoded.map(codecs.fromTaggedJson), values);
    expect(codecs.fromTaggedJson(encoded[0]), isA<_NativeId>());
    expect(codecs.fromTaggedJson(encoded[1]), isA<_ScopedId>());
  });

  test('key codecs reject lossy encoding and noncanonical aliases', () {
    final lossy = IdentityCodecRegistry()
      ..register<_NativeId>('lossy', const _LossyNativeCodec());
    expect(
      () => lossy.toKey(const _NativeId('IssueA')),
      throwsA(isA<SerializationException>()),
    );
    expect(
      () => lossy.fromKey<_NativeId>('IssueA'),
      throwsA(isA<DeserializationException>()),
    );
    expect(
      () => registry().fromKey<_ScopedId>('[ "repo", 12 ]'),
      throwsA(isA<DeserializationException>()),
    );
  });

  test('unregistered, duplicate and malformed codec declarations fail clearly',
      () {
    final codecs = IdentityCodecRegistry();
    expect(codecs.contains<_NativeId>(), isFalse);
    expect(
      () => codecs.toJson(const _NativeId('native')),
      throwsA(isA<SerializationException>()),
    );
    expect(
      () => codecs.toTaggedJson(const _NativeId('native')),
      throwsA(isA<SerializationException>()),
    );
    expect(
      () => codecs.register<_NativeId>('uuid', const _NativeCodec()),
      throwsArgumentError,
    );
    codecs.register<_NativeId>('native', const _NativeCodec());
    expect(
      () => codecs.register<_NativeId>('again', const _NativeCodec()),
      throwsArgumentError,
    );
    expect(
      () => codecs.register<_ScopedId>(' ', const _ScopedCodec()),
      throwsArgumentError,
    );
    for (final json in <Object?>[
      null,
      12,
      {},
      {'type': 'uuid'},
      {'type': 'unknown', 'value': '12'},
    ]) {
      expect(
        () => codecs.fromTaggedJson(json),
        throwsA(isA<DeserializationException>()),
      );
    }
    expect(IdentityCodecRegistry().contains<_NativeId>(), isFalse);
  });
}
