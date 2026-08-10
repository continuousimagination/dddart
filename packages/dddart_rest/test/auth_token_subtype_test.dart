import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

part 'auth_token_subtype_test.g.dart';

@Serializable()
class CustomRefreshToken extends RefreshToken {
  CustomRefreshToken({
    required super.id,
    required super.userId,
    required super.token,
    required super.expiresAt,
    required this.storagePartition,
    required super.createdAt,
    required super.updatedAt,
    super.revoked,
    super.deviceInfo,
  });

  final String storagePartition;
}

@Serializable()
class CustomDeviceCode extends DeviceCode {
  CustomDeviceCode({
    required super.id,
    required super.deviceCode,
    required super.userCode,
    required super.clientId,
    required super.expiresAt,
    required this.verificationChannel,
    required super.createdAt,
    required super.updatedAt,
    super.userId,
    super.status,
  });

  final String verificationChannel;
}

final class CustomRefreshTokenLifecycle
    implements RefreshTokenLifecycle<CustomRefreshToken> {
  const CustomRefreshTokenLifecycle();

  @override
  CustomRefreshToken create({
    required UuidValue id,
    required String userId,
    required String token,
    required DateTime expiresAt,
    required String? deviceInfo,
    required DateTime createdAt,
  }) {
    return CustomRefreshToken(
      id: id,
      userId: userId,
      token: token,
      expiresAt: expiresAt,
      storagePartition: 'refresh:$userId',
      deviceInfo: deviceInfo,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @override
  CustomRefreshToken revoke(
    CustomRefreshToken current, {
    required DateTime revokedAt,
  }) {
    return CustomRefreshToken(
      id: current.id,
      userId: current.userId,
      token: current.token,
      expiresAt: current.expiresAt,
      storagePartition: current.storagePartition,
      revoked: true,
      deviceInfo: current.deviceInfo,
      createdAt: current.createdAt,
      updatedAt: revokedAt,
    );
  }
}

final class CustomDeviceCodeLifecycle
    implements DeviceCodeLifecycle<CustomDeviceCode> {
  const CustomDeviceCodeLifecycle();

  @override
  CustomDeviceCode create({
    required UuidValue id,
    required String deviceCode,
    required String userCode,
    required String clientId,
    required DateTime expiresAt,
    required DateTime createdAt,
  }) {
    return CustomDeviceCode(
      id: id,
      deviceCode: deviceCode,
      userCode: userCode,
      clientId: clientId,
      expiresAt: expiresAt,
      verificationChannel: 'device:$clientId',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @override
  CustomDeviceCode approve(
    CustomDeviceCode current, {
    required String userId,
    required DateTime approvedAt,
  }) {
    return CustomDeviceCode(
      id: current.id,
      deviceCode: current.deviceCode,
      userCode: current.userCode,
      clientId: current.clientId,
      expiresAt: current.expiresAt,
      verificationChannel: current.verificationChannel,
      userId: userId,
      status: DeviceCodeStatus.approved,
      createdAt: current.createdAt,
      updatedAt: approvedAt,
    );
  }

  @override
  CustomDeviceCode consume(
    CustomDeviceCode current, {
    required DateTime consumedAt,
  }) {
    return CustomDeviceCode(
      id: current.id,
      deviceCode: current.deviceCode,
      userCode: current.userCode,
      clientId: current.clientId,
      expiresAt: current.expiresAt,
      verificationChannel: current.verificationChannel,
      userId: current.userId,
      status: DeviceCodeStatus.consumed,
      createdAt: current.createdAt,
      updatedAt: consumedAt,
    );
  }
}

void main() {
  group('typed authentication lifecycles', () {
    test(
      'refresh issuance, lookup, and revocation preserve custom subtype state',
      () async {
        final inMemoryRepository =
            InMemoryRefreshTokenRepository<CustomRefreshToken>();
        final RefreshTokenRepository<CustomRefreshToken> repository =
            inMemoryRepository;
        final claimsLoaderCalls = <String>[];
        final handler = JwtAuthHandler<StandardClaims, CustomRefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: repository,
          refreshTokenLifecycle: const CustomRefreshTokenLifecycle(),
          claimsLoader: (userId) async {
            claimsLoaderCalls.add(userId);
            return StandardClaims(sub: userId, email: '$userId@example.com');
          },
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
        );

        final issued = await handler.issueTokens(
          'custom-user',
          deviceInfo: 'custom-device',
        );
        final storedAfterIssue = inMemoryRepository.getAllSync().single;

        expect(storedAfterIssue, isA<CustomRefreshToken>());
        expect(storedAfterIssue.runtimeType, CustomRefreshToken);
        expect(storedAfterIssue.storagePartition, 'refresh:custom-user');
        expect(storedAfterIssue.userId, 'custom-user');
        expect(storedAfterIssue.token, issued.refreshToken);
        expect(storedAfterIssue.deviceInfo, 'custom-device');
        expect(storedAfterIssue.revoked, isFalse);
        expect(storedAfterIssue.createdAt, storedAfterIssue.updatedAt);

        final refreshed = await handler.refresh(issued.refreshToken);

        expect(refreshed.refreshToken, issued.refreshToken);
        expect(claimsLoaderCalls, ['custom-user', 'custom-user']);
        expect(
          inMemoryRepository.getAllSync().single,
          same(storedAfterIssue),
        );

        await handler.revoke(issued.refreshToken);
        final storedAfterRevoke = inMemoryRepository.getAllSync().single;

        expect(storedAfterRevoke, isA<CustomRefreshToken>());
        expect(storedAfterRevoke.runtimeType, CustomRefreshToken);
        expect(storedAfterRevoke.storagePartition, 'refresh:custom-user');
        expect(storedAfterRevoke.id, storedAfterIssue.id);
        expect(storedAfterRevoke.userId, storedAfterIssue.userId);
        expect(storedAfterRevoke.token, storedAfterIssue.token);
        expect(storedAfterRevoke.expiresAt, storedAfterIssue.expiresAt);
        expect(storedAfterRevoke.deviceInfo, storedAfterIssue.deviceInfo);
        expect(storedAfterRevoke.createdAt, storedAfterIssue.createdAt);
        expect(
          storedAfterRevoke.updatedAt.isBefore(storedAfterIssue.updatedAt),
          isFalse,
        );
        expect(storedAfterRevoke.revoked, isTrue);

        final serializer = CustomRefreshTokenJsonSerializer();
        final restored = serializer.deserialize(
          serializer.serialize(storedAfterRevoke),
        );

        expect(restored, isA<CustomRefreshToken>());
        expect(restored.storagePartition, storedAfterRevoke.storagePartition);
        expect(restored.id, storedAfterRevoke.id);
        expect(restored.userId, storedAfterRevoke.userId);
        expect(restored.token, storedAfterRevoke.token);
        expect(restored.expiresAt, storedAfterRevoke.expiresAt);
        expect(restored.revoked, isTrue);
        expect(restored.deviceInfo, storedAfterRevoke.deviceInfo);
        expect(restored.createdAt, storedAfterRevoke.createdAt);
        expect(restored.updatedAt, storedAfterRevoke.updatedAt);
      },
    );

    test(
      'device creation and approval preserve custom subtype state',
      () async {
        final refreshTokens = InMemoryRefreshTokenRepository<RefreshToken>();
        final authHandler = JwtAuthHandler<StandardClaims, RefreshToken>(
          secret: 'test-secret-key-for-testing',
          refreshTokenRepository: refreshTokens,
          refreshTokenLifecycle: const StandardRefreshTokenLifecycle(),
          claimsLoader: (userId) async => StandardClaims(sub: userId),
          parseClaimsFromJson: StandardClaims.fromJson,
          claimsToJson: (claims) => claims.toJson(),
        );
        const deviceCodeLifecycle = CustomDeviceCodeLifecycle();
        final inMemoryRepository =
            InMemoryDeviceCodeRepository<CustomDeviceCode>(
          lifecycle: deviceCodeLifecycle,
        );
        final DeviceCodeRepository<CustomDeviceCode> deviceCodeRepository =
            inMemoryRepository;
        final Repository<CustomDeviceCode> repository = deviceCodeRepository;
        expect(repository, same(inMemoryRepository));
        final endpoints =
            AuthEndpoints<StandardClaims, RefreshToken, CustomDeviceCode>(
          authHandler: authHandler,
          deviceCodeRepository: deviceCodeRepository,
          deviceCodeLifecycle: deviceCodeLifecycle,
          userValidator: (username, password) async {
            if (username == 'custom-user' && password == 'correct-password') {
              return 'custom-user-id';
            }
            return null;
          },
        );

        final createResponse = await endpoints.handleDeviceCode(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/device'),
            body: jsonEncode({'client_id': 'custom-client'}),
          ),
        );
        final createJson = jsonDecode(await createResponse.readAsString())
            as Map<String, dynamic>;
        final storedAfterCreate = inMemoryRepository.getAllSync().single;

        expect(createResponse.statusCode, 200);
        expect(storedAfterCreate, isA<CustomDeviceCode>());
        expect(storedAfterCreate.runtimeType, CustomDeviceCode);
        expect(storedAfterCreate.verificationChannel, 'device:custom-client');
        expect(storedAfterCreate.deviceCode, createJson['device_code']);
        expect(storedAfterCreate.userCode, createJson['user_code']);
        expect(storedAfterCreate.clientId, 'custom-client');
        expect(storedAfterCreate.userId, isNull);
        expect(storedAfterCreate.status, DeviceCodeStatus.pending);
        expect(storedAfterCreate.createdAt, storedAfterCreate.updatedAt);

        final approvalResponse = await endpoints.handleDeviceVerify(
          Request(
            'POST',
            Uri.parse('http://localhost/auth/device/verify'),
            body: 'user_code=${storedAfterCreate.userCode}'
                '&username=custom-user&password=correct-password',
            headers: {
              'content-type': 'application/x-www-form-urlencoded',
            },
          ),
        );
        final storedAfterApproval = inMemoryRepository.getAllSync().single;

        expect(approvalResponse.statusCode, 200);
        expect(storedAfterApproval, isA<CustomDeviceCode>());
        expect(storedAfterApproval.runtimeType, CustomDeviceCode);
        expect(
          storedAfterApproval.verificationChannel,
          storedAfterCreate.verificationChannel,
        );
        expect(storedAfterApproval.id, storedAfterCreate.id);
        expect(storedAfterApproval.deviceCode, storedAfterCreate.deviceCode);
        expect(storedAfterApproval.userCode, storedAfterCreate.userCode);
        expect(storedAfterApproval.clientId, storedAfterCreate.clientId);
        expect(storedAfterApproval.expiresAt, storedAfterCreate.expiresAt);
        expect(storedAfterApproval.createdAt, storedAfterCreate.createdAt);
        expect(
          storedAfterApproval.updatedAt.isBefore(storedAfterCreate.updatedAt),
          isFalse,
        );
        expect(storedAfterApproval.userId, 'custom-user-id');
        expect(storedAfterApproval.status, DeviceCodeStatus.approved);

        final consumedAt = storedAfterApproval.updatedAt.add(
          const Duration(milliseconds: 1),
        );
        final consumed = await deviceCodeRepository.consumeApproved(
          deviceCode: storedAfterApproval.deviceCode,
          clientId: storedAfterApproval.clientId,
          consumedAt: consumedAt,
        );

        expect(consumed, isNotNull);
        expect(consumed, isA<CustomDeviceCode>());
        expect(consumed!.runtimeType, CustomDeviceCode);
        expect(
          consumed.verificationChannel,
          storedAfterApproval.verificationChannel,
        );
        expect(consumed.id, storedAfterApproval.id);
        expect(consumed.deviceCode, storedAfterApproval.deviceCode);
        expect(consumed.userCode, storedAfterApproval.userCode);
        expect(consumed.clientId, storedAfterApproval.clientId);
        expect(consumed.expiresAt, storedAfterApproval.expiresAt);
        expect(consumed.userId, storedAfterApproval.userId);
        expect(consumed.status, DeviceCodeStatus.consumed);
        expect(consumed.createdAt, storedAfterApproval.createdAt);
        expect(consumed.updatedAt, consumedAt);

        final serializer = CustomDeviceCodeJsonSerializer();
        final restored = serializer.deserialize(
          serializer.serialize(consumed),
        );

        expect(restored, isA<CustomDeviceCode>());
        expect(
          restored.verificationChannel,
          consumed.verificationChannel,
        );
        expect(restored.id, consumed.id);
        expect(restored.deviceCode, consumed.deviceCode);
        expect(restored.userCode, consumed.userCode);
        expect(restored.clientId, consumed.clientId);
        expect(restored.expiresAt, consumed.expiresAt);
        expect(restored.userId, consumed.userId);
        expect(restored.status, DeviceCodeStatus.consumed);
        expect(restored.createdAt, consumed.createdAt);
        expect(restored.updatedAt, consumed.updatedAt);
      },
    );
  });
}
