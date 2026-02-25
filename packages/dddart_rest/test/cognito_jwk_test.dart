import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Test to fetch real Cognito JWK and test PEM conversion
void main() {
  test('fetch real Cognito JWK and inspect structure', () async {
    // Fetch JWKS from Cognito
    final response = await http.get(
      Uri.parse(
        'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_hRCu4QkPm/.well-known/jwks.json',
      ),
    );

    expect(response.statusCode, equals(200));

    final jwks = jsonDecode(response.body) as Map<String, dynamic>;
    final keys = jwks['keys'] as List<dynamic>;

    expect(keys, isNotEmpty);

    // Find the key with kid: 1NJLVIpov771+nmbt4hbWicx3hvd7Nkoo7qiS5WNrpE=
    final key = keys.firstWhere(
      (k) => k['kid'] == '1NJLVIpov771+nmbt4hbWicx3hvd7Nkoo7qiS5WNrpE=',
    ) as Map<String, dynamic>;

    print('Key found:');
    print('  kty: ${key['kty']}');
    print('  alg: ${key['alg']}');
    print('  use: ${key['use']}');

    // Try to decode n and e
    final n = key['n'] as String;
    final e = key['e'] as String;

    print('  n length: ${n.length}');
    print('  e length: ${e.length}');
    print('  n has newlines: ${n.contains('\n')}');
    print('  n has spaces: ${n.contains(' ')}');

    // Check if n length is multiple of 4
    print('  n length % 4: ${n.length % 4}');

    // Try decoding with proper padding
    var nPadded = n;
    while (nPadded.length % 4 != 0) {
      nPadded += '=';
    }
    print('  n padded length: ${nPadded.length}');

    // Try both methods
    try {
      final nBytes1 = base64Url.decode(n);
      print('  base64Url.decode(n) succeeded: ${nBytes1.length} bytes');
    } catch (e) {
      print('  base64Url.decode(n) failed: $e');
    }

    try {
      final nBytes2 = base64Url.decode(nPadded);
      print('  base64Url.decode(nPadded) succeeded: ${nBytes2.length} bytes');
    } catch (e) {
      print('  base64Url.decode(nPadded) failed: $e');
    }

    final nBytes = base64Url.decode(nPadded);
    final eBytes = base64Url.decode(e);

    print('  n bytes length: ${nBytes.length}');
    print('  e bytes length: ${eBytes.length}');
  });
}
