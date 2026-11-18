import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../example/custom_verifier_example.dart';

void main() {
  const secret = 'local-test-secret';
  const body = '{"event":"user.created","userId":"123"}';

  Future<MyVerificationResult> verify(String timestamp) {
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('$timestamp:$body'))
        .toString();
    return MyWebhookVerifier(secret: secret).verify(
      Request('POST', Uri.parse('http://localhost/webhooks/custom'), headers: {
        'x-webhook-signature': signature,
        'x-webhook-timestamp': timestamp,
      }),
      body,
    );
  }

  test('custom verifier accepts a correctly signed current timestamp',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect((await verify('$now')).isValid, isTrue);
  });

  test('custom verifier rejects correctly signed past and future replays',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final offset in [-3600, 3600]) {
      expect((await verify('${now + offset}')).isValid, isFalse);
    }
  });

  test('malformed and out-of-range timestamps fail without throwing', () async {
    for (final timestamp in ['invalid', '8640000000001', '-8640000000001']) {
      expect((await verify(timestamp)).isValid, isFalse);
    }
  });
}
