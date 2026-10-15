import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('begin, reload, and complete bind PKCE and persist credentials once',
      () async {
    final fixture = _Fixture();
    final url =
        await fixture.provider().beginLogin(forceReauthentication: true);
    final transaction = Map<String, dynamic>.from(fixture.login.value!);
    final verifier = transaction['verifier'] as String;
    expect(url.path, '/oauth2/authorize');
    expect(url.queryParameters['state'], transaction['state']);
    expect(url.queryParameters['nonce'], transaction['nonce']);
    expect(url.queryParameters['client_id'], 'client');
    expect(url.queryParameters['redirect_uri'], _redirect);
    expect(url.queryParameters['prompt'], 'login');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(
      url.queryParameters['code_challenge'],
      base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', ''),
    );
    expect(url.toString(), isNot(contains(verifier)));
    expect(fixture.credentials.writes, 0);

    fixture.claims = {'nonce': transaction['nonce'], 'aud': 'client'};
    final resumed = fixture.provider();
    final callback = CallbackResult(
      code: 'authorization-code',
      state: url.queryParameters['state']!,
    );
    await resumed.completeLogin(callback);
    expect(fixture.exchanges, 1);
    expect(fixture.form, {
      'grant_type': 'authorization_code',
      'client_id': 'client',
      'code': 'authorization-code',
      'redirect_uri': _redirect,
      'code_verifier': verifier,
    });
    expect(fixture.login.value, isNull);
    expect(fixture.credentials.writes, 1);
    expect(await resumed.getAccessToken(), 'access');
    expect(await resumed.getIdToken(), fixture.idToken);
    await expectLater(
      fixture.provider().completeLogin(callback),
      throwsA(isA<AuthenticationException>()),
    );
    expect(fixture.exchanges, 1);
    expect(fixture.credentials.writes, 1);
  });

  for (final field in ['state', 'client_id', 'domain', 'redirect_uri']) {
    test('rejects a $field mismatch before exchange and consumes state',
        () async {
      final fixture = _Fixture();
      final callback = await fixture.begin();
      fixture.login.value![field] = 'mismatch';
      await _expectRejected(fixture, callback);
      expect(fixture.exchanges, 0);
    });
  }

  for (final offset in [
    const Duration(minutes: -11),
    const Duration(minutes: 2),
  ]) {
    test('rejects transaction timestamp offset $offset', () async {
      final fixture = _Fixture();
      final callback = await fixture.begin();
      fixture.login.value!['created_at'] =
          DateTime.now().toUtc().add(offset).toIso8601String();
      await _expectRejected(fixture, callback);
      expect(fixture.exchanges, 0);
    });
  }

  for (final error in [true, false]) {
    test('rejects ${error ? 'OAuth error' : 'missing code'} before exchange',
        () async {
      final fixture = _Fixture();
      final original = await fixture.begin();
      final callback = CallbackResult(
        code: error ? original.code : '',
        state: original.state,
        error: error ? 'access_denied' : null,
      );
      await _expectRejected(fixture, callback);
      expect(fixture.exchanges, 0);
    });
  }

  test('rejects a callback without a pending login', () async {
    final fixture = _Fixture();
    await _expectRejected(
      fixture,
      CallbackResult(code: 'code', state: 'state'),
    );
    expect(fixture.exchanges, 0);
  });

  for (final field in ['nonce', 'aud']) {
    test('rejects wrong $field without writing credentials', () async {
      final fixture = _Fixture();
      final callback = await fixture.begin();
      fixture.claims[field] = 'wrong';
      await _expectRejected(fixture, callback);
      expect(fixture.exchanges, 1);
    });
  }

  for (final token in [
    'not-a-jwt',
    'header.%.signature',
    'header.${base64Url.encode(utf8.encode('not json'))}.signature',
    'header.${base64Url.encode(utf8.encode('[]'))}.signature',
    'header.${base64Url.encode(utf8.encode('null'))}.signature',
    'header.${base64Url.encode(utf8.encode('{}'))}.signature',
  ]) {
    test('rejects malformed or missing ID claims: $token', () async {
      final fixture = _Fixture();
      final callback = await fixture.begin();
      fixture.tokenOverride = token;
      await _expectRejected(fixture, callback);
      expect(fixture.exchanges, 1);
    });
  }

  test('failed token exchange consumes state without writing credentials',
      () async {
    final fixture = _Fixture();
    final callback = await fixture.begin();
    fixture.status = 400;
    await _expectRejected(fixture, callback);
    expect(fixture.exchanges, 1);
  });
}

const _redirect = 'https://app.example/callback';

Future<void> _expectRejected(_Fixture fixture, CallbackResult callback) async {
  final originalCredentials =
      Map<String, dynamic>.from(fixture.credentials.value!);
  await expectLater(
    fixture.provider().completeLogin(callback),
    throwsA(isA<AuthenticationException>()),
  );
  expect(fixture.login.value, isNull);
  expect(fixture.credentials.writes, 0);
  expect(fixture.credentials.value, originalCredentials);
  final exchanges = fixture.exchanges;
  await expectLater(
    fixture.provider().completeLogin(callback),
    throwsA(isA<AuthenticationException>()),
  );
  expect(fixture.exchanges, exchanges);
  expect(fixture.credentials.writes, 0);
}

class _Fixture {
  final login = _LoginStore();
  final credentials = _CredentialStore();
  Map<String, dynamic> claims = {};
  Map<String, String>? form;
  String? tokenOverride;
  int exchanges = 0;
  int status = 200;

  String get idToken =>
      tokenOverride ??
      'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';

  CognitoAuthProvider provider() => CognitoAuthProvider(
        cognitoDomain: 'https://provider.example',
        clientId: 'client',
        credentialStore: credentials,
        loginStore: login,
        callbackStrategy: ManualCallbackStrategy(redirectUri: _redirect),
        httpClient: MockClient((request) async {
          exchanges++;
          expect(
            request.url.toString(),
            'https://provider.example/oauth2/token',
          );
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            startsWith('application/x-www-form-urlencoded'),
          );
          expect(login.value, isNull, reason: 'Consume state before exchange');
          form = Uri.splitQueryString(request.body);
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'id_token': idToken,
              'refresh_token': 'refresh',
              'expires_in': 3600,
            }),
            status,
          );
        }),
      );

  Future<CallbackResult> begin() async {
    final url = await provider().beginLogin();
    expect(url.queryParameters['prompt'], 'select_account');
    claims = {'nonce': url.queryParameters['nonce'], 'aud': 'client'};
    return CallbackResult(code: 'code', state: url.queryParameters['state']!);
  }
}

class _LoginStore implements OAuthLoginStore {
  Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> load() async => value == null
      ? null
      : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<void> save(Map<String, dynamic> transaction) async {
    // Serialize to simulate persistence across a browser reload.
    value = jsonDecode(jsonEncode(transaction)) as Map<String, dynamic>;
  }

  @override
  Future<void> clear() async => value = null;
}

class _CredentialStore implements OAuthCredentialStore {
  Map<String, dynamic>? value = {'existing': 'credentials'};
  int writes = 0;

  @override
  Future<Map<String, dynamic>?> load() async => value;

  @override
  Future<void> save(Map<String, dynamic> credentials) async {
    writes++;
    value = Map.from(credentials);
  }

  @override
  Future<void> clear() async => value = null;
}
