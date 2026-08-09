import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('single-use client-bound device grants', () {
    test('in-memory atomic consume enforces every eligibility predicate',
        () async {
      const lifecycle = StandardDeviceCodeLifecycle();
      final repository = InMemoryDeviceCodeRepository<DeviceCode>(
        lifecycle: lifecycle,
      );
      final now = DateTime.now();
      final missingUser = DeviceCode(
        id: UuidValue.generate(),
        deviceCode: 'missing-user',
        userCode: 'MISS-USER',
        clientId: 'owner-client',
        expiresAt: now.add(const Duration(minutes: 1)),
        status: DeviceCodeStatus.approved,
        createdAt: now,
        updatedAt: now,
      );
      final expired = DeviceCode(
        id: UuidValue.generate(),
        deviceCode: 'expired-code',
        userCode: 'EXPR-CODE',
        clientId: 'owner-client',
        expiresAt: now.subtract(const Duration(seconds: 1)),
        userId: 'device-user',
        status: DeviceCodeStatus.approved,
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now,
      );
      await repository.save(missingUser);
      await repository.save(expired);

      expect(
        await repository.consumeApproved(
          deviceCode: missingUser.deviceCode,
          clientId: missingUser.clientId,
          consumedAt: now,
        ),
        isNull,
      );
      expect(
        await repository.consumeApproved(
          deviceCode: expired.deviceCode,
          clientId: expired.clientId,
          consumedAt: now,
        ),
        isNull,
      );
      expect(
        await repository.consumeApproved(
          deviceCode: expired.deviceCode,
          clientId: 'other-client',
          consumedAt: now,
        ),
        isNull,
      );
      expect(await repository.getById(missingUser.id), same(missingUser));
      expect(await repository.getById(expired.id), same(expired));
    });

    test('a different client receives invalid_grant without consuming',
        () async {
      final fixture = _DeviceGrantFixture();
      final approved = await fixture.seedApprovedCode();

      final mismatchResponse = await fixture.redeem(
        approved.deviceCode,
        clientId: 'other-client',
      );
      final mismatchJson = jsonDecode(await mismatchResponse.readAsString())
          as Map<String, dynamic>;

      expect(mismatchResponse.statusCode, 400);
      expect(mismatchJson['error'], 'invalid_grant');
      expect(
        (await fixture.deviceCodes.findByDeviceCode(approved.deviceCode))
            ?.status,
        DeviceCodeStatus.approved,
      );
      expect(fixture.refreshTokens.getAllSync(), isEmpty);

      final ownerResponse = await fixture.redeem(
        approved.deviceCode,
        clientId: approved.clientId,
      );

      expect(ownerResponse.statusCode, 200);
      expect(
        (await fixture.deviceCodes.findByDeviceCode(approved.deviceCode))
            ?.status,
        DeviceCodeStatus.consumed,
      );
      expect(fixture.refreshTokens.getAllSync(), hasLength(1));
    });

    test('an approved grant returns tokens once and then invalid_grant',
        () async {
      final fixture = _DeviceGrantFixture();
      final approved = await fixture.seedApprovedCode();

      final firstResponse = await fixture.redeem(
        approved.deviceCode,
        clientId: approved.clientId,
      );
      final firstJson = jsonDecode(await firstResponse.readAsString())
          as Map<String, dynamic>;

      expect(firstResponse.statusCode, 200);
      expect(firstJson['access_token'], isA<String>());
      expect(firstJson['refresh_token'], isA<String>());
      expect(
        (await fixture.deviceCodes.findByDeviceCode(approved.deviceCode))
            ?.status,
        DeviceCodeStatus.consumed,
      );
      expect(fixture.refreshTokens.getAllSync(), hasLength(1));

      final replayResponse = await fixture.redeem(
        approved.deviceCode,
        clientId: approved.clientId,
      );
      final replayJson = jsonDecode(await replayResponse.readAsString())
          as Map<String, dynamic>;

      expect(replayResponse.statusCode, 400);
      expect(replayJson['error'], 'invalid_grant');
      expect(fixture.refreshTokens.getAllSync(), hasLength(1));

      await fixture.deviceCodes.save(
        DeviceCode(
          id: approved.id,
          deviceCode: approved.deviceCode,
          userCode: approved.userCode,
          clientId: approved.clientId,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          userId: approved.userId,
          status: DeviceCodeStatus.consumed,
          createdAt: approved.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      final replayAfterExpiry = await fixture.redeem(
        approved.deviceCode,
        clientId: approved.clientId,
      );
      final replayAfterExpiryJson = jsonDecode(
        await replayAfterExpiry.readAsString(),
      ) as Map<String, dynamic>;

      expect(replayAfterExpiry.statusCode, 400);
      expect(replayAfterExpiryJson['error'], 'invalid_grant');
      expect(fixture.refreshTokens.getAllSync(), hasLength(1));
    });

    test('two simultaneous redemptions have exactly one winner', () async {
      final innerRepository = InMemoryDeviceCodeRepository<DeviceCode>(
        lifecycle: const StandardDeviceCodeLifecycle(),
      );
      final barrierRepository = _LookupBarrierDeviceCodeRepository(
        innerRepository,
      );
      final fixture = _DeviceGrantFixture(repository: barrierRepository);
      final approved = await fixture.seedApprovedCode();

      final responses = await Future.wait([
        fixture.redeem(approved.deviceCode, clientId: approved.clientId),
        fixture.redeem(approved.deviceCode, clientId: approved.clientId),
      ]);
      final responseBodies = await Future.wait(
        responses.map((response) => response.readAsString()),
      );

      final statusCodes =
          responses.map((response) => response.statusCode).toList()..sort();
      expect(statusCodes, [200, 400]);
      final losingBody = jsonDecode(
        responseBodies[
            responses.indexWhere((response) => response.statusCode == 400)],
      ) as Map<String, dynamic>;
      expect(losingBody['error'], 'invalid_grant');
      expect(barrierRepository.deviceCodeLookupCount, 2);
      expect(barrierRepository.successfulConsumptions, 1);
      expect(
        innerRepository.getAllSync().single.status,
        DeviceCodeStatus.consumed,
      );
      expect(fixture.refreshTokens.getAllSync(), hasLength(1));
      expect(fixture.claimsLoaderCalls, ['device-user']);
    });
  });
}

final class _DeviceGrantFixture {
  _DeviceGrantFixture({DeviceCodeRepository<DeviceCode>? repository})
      : deviceCodes = repository ??
            InMemoryDeviceCodeRepository<DeviceCode>(
              lifecycle: const StandardDeviceCodeLifecycle(),
            ) {
    authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
      secret: 'test-secret-key-for-device-grants',
      refreshTokenRepository: refreshTokens,
      refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
      claimsLoader: (userId) async {
        claimsLoaderCalls.add(userId);
        return StandardClaims(sub: userId);
      },
      parseClaimsFromJson: StandardClaims.fromJson,
      claimsToJson: (claims) => claims.toJson(),
    );
    endpoints = AuthEndpoints<StandardClaims, RefreshToken, DeviceCode>(
      authHandler: authHandler,
      deviceCodeRepository: deviceCodes,
      deviceCodeLifecycle: const StandardDeviceCodeLifecycle(),
      userValidator: (_, __) async => null,
    );
  }

  final refreshTokens = InMemoryRepository<RefreshToken>();
  final List<String> claimsLoaderCalls = [];
  final DeviceCodeRepository<DeviceCode> deviceCodes;
  late final JwtAuthHandler<StandardClaims, RefreshToken> authHandler;
  late final AuthEndpoints<StandardClaims, RefreshToken, DeviceCode> endpoints;

  Future<DeviceCode> seedApprovedCode() async {
    final now = DateTime.now();
    final pending = const StandardDeviceCodeLifecycle().create(
      id: UuidValue.generate(),
      deviceCode: 'opaque-device-code',
      userCode: 'ABCD-EFGH',
      clientId: 'owner-client',
      expiresAt: now.add(const Duration(minutes: 10)),
      createdAt: now,
    );
    final approved = const StandardDeviceCodeLifecycle().approve(
      pending,
      userId: 'device-user',
      approvedAt: now,
    );
    await deviceCodes.save(approved);
    return approved;
  }

  Future<Response> redeem(String deviceCode, {required String clientId}) {
    return endpoints.handleToken(
      Request(
        'POST',
        Uri.parse('http://localhost/auth/token'),
        body: jsonEncode({
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode,
          'client_id': clientId,
        }),
      ),
    );
  }
}

final class _LookupBarrierDeviceCodeRepository
    implements DeviceCodeRepository<DeviceCode> {
  _LookupBarrierDeviceCodeRepository(this._delegate);

  final InMemoryDeviceCodeRepository<DeviceCode> _delegate;
  final Completer<void> _bothLookupsComplete = Completer<void>();
  int deviceCodeLookupCount = 0;
  int successfulConsumptions = 0;

  @override
  Future<DeviceCode?> findByDeviceCode(String deviceCode) async {
    final result = await _delegate.findByDeviceCode(deviceCode);
    deviceCodeLookupCount++;
    if (deviceCodeLookupCount == 2) {
      _bothLookupsComplete.complete();
    }
    await _bothLookupsComplete.future;
    return result;
  }

  @override
  Future<DeviceCode?> consumeApproved({
    required String deviceCode,
    required String clientId,
    required DateTime consumedAt,
  }) async {
    final result = await _delegate.consumeApproved(
      deviceCode: deviceCode,
      clientId: clientId,
      consumedAt: consumedAt,
    );
    if (result != null) {
      successfulConsumptions++;
    }
    return result;
  }

  @override
  Future<void> deleteById(UuidValue id) => _delegate.deleteById(id);

  @override
  Future<DeviceCode?> findByUserCode(String userCode) =>
      _delegate.findByUserCode(userCode);

  @override
  Future<DeviceCode> getById(UuidValue id) => _delegate.getById(id);

  @override
  Future<void> save(DeviceCode aggregate) => _delegate.save(aggregate);
}
