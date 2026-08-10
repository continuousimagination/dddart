import 'package:dddart/dddart.dart';
import 'package:dddart_rest/src/device_code.dart';

/// Constructs and transitions device codes without erasing their type.
///
/// Implementations for custom [DeviceCode] subtypes must preserve all
/// subtype-specific state when [approve] and [consume] create transitioned
/// copies.
abstract interface class DeviceCodeLifecycle<T extends DeviceCode> {
  /// Creates a pending device code of type [T].
  T create({
    required UuidValue id,
    required String deviceCode,
    required String userCode,
    required String clientId,
    required DateTime expiresAt,
    required DateTime createdAt,
  });

  /// Creates an approved copy of [current] while preserving its concrete type.
  T approve(
    T current, {
    required String userId,
    required DateTime approvedAt,
  });

  /// Creates a consumed copy of [current] while preserving its concrete type.
  T consume(T current, {required DateTime consumedAt});
}

/// Standard lifecycle for the base [DeviceCode] type.
final class StandardDeviceCodeLifecycle
    implements DeviceCodeLifecycle<DeviceCode> {
  /// Creates the standard device-code lifecycle.
  const StandardDeviceCodeLifecycle();

  @override
  DeviceCode create({
    required UuidValue id,
    required String deviceCode,
    required String userCode,
    required String clientId,
    required DateTime expiresAt,
    required DateTime createdAt,
  }) {
    return DeviceCode(
      id: id,
      deviceCode: deviceCode,
      userCode: userCode,
      clientId: clientId,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @override
  DeviceCode approve(
    DeviceCode current, {
    required String userId,
    required DateTime approvedAt,
  }) {
    return DeviceCode(
      id: current.id,
      deviceCode: current.deviceCode,
      userCode: current.userCode,
      clientId: current.clientId,
      expiresAt: current.expiresAt,
      userId: userId,
      status: DeviceCodeStatus.approved,
      createdAt: current.createdAt,
      updatedAt: approvedAt,
    );
  }

  @override
  DeviceCode consume(
    DeviceCode current, {
    required DateTime consumedAt,
  }) {
    return DeviceCode(
      id: current.id,
      deviceCode: current.deviceCode,
      userCode: current.userCode,
      clientId: current.clientId,
      expiresAt: current.expiresAt,
      userId: current.userId,
      status: DeviceCodeStatus.consumed,
      createdAt: current.createdAt,
      updatedAt: consumedAt,
    );
  }
}
