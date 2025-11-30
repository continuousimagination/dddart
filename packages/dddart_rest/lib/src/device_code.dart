import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Status of a device code in the device flow
enum DeviceCodeStatus {
  /// Device code is pending user approval
  pending,

  /// Device code has been approved by user
  approved,

  /// Device code was denied by user
  denied,

  /// Device code has expired
  expired,
}

/// Device code for device flow authentication
///
/// Device codes enable authentication on devices with limited input
/// capabilities (CLI tools, smart TVs) by having users enter a short
/// code in a browser to authorize the device.
///
/// Note: DeviceCode extends AggregateRoot for persistence convenience,
/// but it is an infrastructure concern, not a domain concept. The Repository
/// pattern is used here as a general-purpose persistence abstraction.
@Serializable()
class DeviceCode extends AggregateRoot {
  /// Creates a device code
  DeviceCode({
    required super.id,
    required this.deviceCode,
    required this.userCode,
    required this.clientId,
    required this.expiresAt,
    this.userId,
    this.status = DeviceCodeStatus.pending,
    super.createdAt,
    super.updatedAt,
  });

  /// The device code (long, random)
  final String deviceCode;

  /// The user code (short, human-readable)
  final String userCode;

  /// Client ID that requested this code
  final String clientId;

  /// When this code expires
  final DateTime expiresAt;

  /// User ID if approved
  final String? userId;

  /// Current status
  final DeviceCodeStatus status;

  /// Checks if code is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Approves the device code for a user
  DeviceCode approve(String userId) {
    return DeviceCode(
      id: id,
      deviceCode: deviceCode,
      userCode: userCode,
      clientId: clientId,
      expiresAt: expiresAt,
      userId: userId,
      status: DeviceCodeStatus.approved,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
