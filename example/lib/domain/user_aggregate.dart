import 'package:dddart/dddart.dart';
import 'user_registered_event.dart';

/// User aggregate root that demonstrates domain event usage.
///
/// This aggregate manages user lifecycle and raises domain events
/// when significant actions occur.
class UserAggregate extends AggregateRoot {
  /// The user's email address.
  final String email;

  /// The user's full name.
  final String fullName;

  /// The organization the user belongs to.
  final String organizationId;

  /// Whether the user's email has been verified.
  bool _emailVerified = false;

  /// Whether the user account is active.
  bool _isActive = true;

  /// Gets whether the user's email is verified.
  bool get emailVerified => _emailVerified;

  /// Gets whether the user account is active.
  bool get isActive => _isActive;

  /// Private constructor for creating a user.
  UserAggregate._({
    required UuidValue id,
    required this.email,
    required this.fullName,
    required this.organizationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  /// Factory method to register a new user.
  ///
  /// This method creates a new user aggregate and raises a UserRegisteredEvent.
  /// This is the proper way to create a user in a domain-driven design,
  /// as it captures the business intent and allows other parts of the system
  /// to react to the registration.
  factory UserAggregate.register({
    required String email,
    required String fullName,
    required String organizationId,
  }) {
    final userId = UuidValue.generate();
    final now = DateTime.now();

    final user = UserAggregate._(
      id: userId,
      email: email,
      fullName: fullName,
      organizationId: organizationId,
      createdAt: now,
      updatedAt: now,
    );

    // Raise domain event to notify the system about the registration
    user.raiseEvent(UserRegisteredEvent(
      userId: userId,
      email: email,
      fullName: fullName,
      organizationId: organizationId,
    ));

    return user;
  }

  /// Verifies the user's email address.
  ///
  /// This method would typically be called after the user clicks a
  /// verification link sent to their email.
  void verifyEmail() {
    if (_emailVerified) {
      throw StateError('Email is already verified');
    }

    _emailVerified = true;

    // In a real application, you might raise an EmailVerifiedEvent here
    // raiseEvent(EmailVerifiedEvent(userId: id.value, email: email));
  }

  /// Deactivates the user account.
  ///
  /// This method suspends the user's access to the system.
  void deactivate() {
    if (!_isActive) {
      throw StateError('User is already deactivated');
    }

    _isActive = false;

    // In a real application, you might raise a UserDeactivatedEvent here
    // raiseEvent(UserDeactivatedEvent(userId: id.value, reason: reason));
  }

  @override
  String toString() {
    return 'UserAggregate(id: ${id.uuid}, email: $email, name: $fullName, verified: $_emailVerified, active: $_isActive)';
  }
}
