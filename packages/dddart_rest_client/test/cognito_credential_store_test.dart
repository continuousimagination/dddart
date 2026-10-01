import 'package:dddart_rest_client/dddart_rest_client.dart';
import 'package:test/test.dart';

class MemoryCredentialStore implements OAuthCredentialStore {
  Map<String, dynamic>? credentials;
  @override
  Future<Map<String, dynamic>?> load() async => credentials;
  @override
  Future<void> save(Map<String, dynamic> value) async => credentials = value;
  @override
  Future<void> clear() async => credentials = null;
}

void main() {
  test('injected storage supplies current tokens and logout clears that store',
      () async {
    final store = MemoryCredentialStore();
    await store.save({
      'access_token': 'synthetic-access',
      'id_token': 'synthetic-id',
      'refresh_token': 'synthetic-refresh',
      'expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    final provider = CognitoAuthProvider(
      cognitoDomain: 'https://synthetic.example',
      clientId: 'synthetic-client',
      credentialStore: store,
    );
    expect(await provider.getAccessToken(), 'synthetic-access');
    expect(await provider.getIdToken(), 'synthetic-id');
    await provider.logout();
    expect(store.credentials, isNull);
    expect(provider.getAccessToken, throwsA(isA<AuthenticationException>()));
  });
}
