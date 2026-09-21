/// Runtime coverage of the generated JWT extension, bypassing injected callbacks.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

part 'claims_codec_test.g.dart';

/// Claims with both nullable scalar and collection fields.
@JwtSerializable()
class MigrationClaims {
  /// Creates synthetic claims.
  const MigrationClaims({required this.name, required this.tags, this.count});

  /// Required scalar.
  final String name;

  /// Required collection.
  final List<String> tags;

  /// Nullable scalar.
  final int? count;
}

void main() {
  final handler = JwtAuthHandler<MigrationClaims, RefreshToken>(
    secret: 'test-only-not-a-live-credential',
    refreshTokenRepository: InMemoryRepository<RefreshToken>(),
    parseClaimsFromJson: (_) =>
        throw StateError('Must exercise generated extension'),
    claimsToJson: (_) => throw StateError('Must exercise generated extension'),
  );
  Map<String, dynamic> encode(MigrationClaims claims) =>
      JwtAuthHandlerMigrationClaimsExtension(handler).claimsToJson(claims);
  MigrationClaims decode(Map<String, dynamic> json) =>
      JwtAuthHandlerMigrationClaimsExtension(handler).parseClaimsFromJson(json);

  test(
    'generated extension round-trips non-null scalar and populated list',
    () {
      final wire = encode(
        const MigrationClaims(name: 'test', tags: ['a', 'b'], count: 7),
      );
      expect(wire, {
        'name': 'test',
        'tags': ['a', 'b'],
        'count': 7,
      });
      final decoded = decode(wire);
      expect(decoded.name, 'test');
      expect(decoded.tags, ['a', 'b']);
      expect(decoded.count, 7);
    },
  );
  test('generated extension round-trips null scalar and empty list', () {
    final wire = encode(const MigrationClaims(name: 'test', tags: []));
    expect(wire.containsKey('count'), isFalse);
    final decoded = decode(wire);
    expect(decoded.count, isNull);
    expect(decoded.tags, isEmpty);
    expect(decode({...wire, 'count': null}).count, isNull);
  });
  test('rejects malformed optional scalar', () {
    expect(
      () => decode({'name': 'test', 'tags': <String>[], 'count': 'seven'}),
      throwsA(isA<TypeError>()),
    );
  });
  test('rejects missing collection and wrong collection elements', () {
    expect(() => decode({'name': 'test'}), throwsA(isA<TypeError>()));
    expect(
      () => decode({
        'name': 'test',
        'tags': [4],
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
