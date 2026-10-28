import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

class _BinaryDialect extends SqlDialect {
  const _BinaryDialect();
  @override
  String get uuidColumnType => 'BLOB';
  @override
  int get maxIdentityKeyBytes => 1024;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const dialect = _BinaryDialect();
  test('SQL identity bytes preserve case, scope, padding and native text', () {
    for (final key in [
      '',
      'IssueA',
      'issuea',
      '12',
      '0012',
      'trailing',
      'trailing ',
      'native/%, café',
      'n\u0000x',
      '["org/repo",12]',
    ]) {
      final encoded = dialect.encodeIdentityKey(key);
      expect(encoded, utf8.encode(key));
      expect(dialect.decodeIdentityKey(encoded), key);
      expect(dialect.decodeIdentityKey(key), key);
    }
    expect(
      dialect.encodeIdentityKey('IssueA'),
      isNot(dialect.encodeIdentityKey('issuea')),
    );
    expect(
      dialect.encodeIdentityKey(List.filled(512, 'é').join()).length,
      1024,
    );
  });

  test('SQL keys reject truncation and malformed Unicode/bytes', () {
    for (final key in [
      List.filled(513, 'é').join(),
      String.fromCharCode(0xd800),
    ]) {
      expect(
        () => dialect.encodeIdentityKey(key),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.constraint,
          ),
        ),
      );
    }
    for (final value in <Object?>[
      null,
      12,
      [0xc3],
      [300],
    ]) {
      expect(
        () => dialect.decodeIdentityKey(value),
        throwsA(isA<DeserializationException>()),
      );
    }
  });
}
