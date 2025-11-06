import 'package:uuid/uuid.dart';
import 'value.dart';

/// A value object that represents a UUID.
/// 
/// This class wraps a UUID string and provides type safety and validation
/// for UUID values used as entity identifiers.
class UuidValue extends Value {
  /// Creates a UuidValue from a UUID string.
  /// 
  /// Throws [ArgumentError] if the provided string is not a valid UUID.
  const UuidValue._(this.uuid);
  
  /// Creates a UuidValue from a UUID string.
  /// 
  /// Throws [ArgumentError] if the provided string is not a valid UUID.
  factory UuidValue.fromString(String uuid) {
    if (!_isValidUuid(uuid)) {
      throw ArgumentError('Invalid UUID format: $uuid');
    }
    return UuidValue._(uuid);
  }
  
  /// Generates a new random UuidValue.
  factory UuidValue.generate() {
    return UuidValue._(const Uuid().v4());
  }
  
  /// The UUID string value.
  final String uuid;
  
  @override
  List<Object?> get props => [uuid];
  
  /// Returns the UUID string representation.
  @override
  String toString() => uuid;
  
  /// Validates if a string is a valid UUID format.
  static bool _isValidUuid(String uuid) {
    // Basic UUID format validation (8-4-4-4-12 hexadecimal digits)
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    return uuidRegex.hasMatch(uuid);
  }
}