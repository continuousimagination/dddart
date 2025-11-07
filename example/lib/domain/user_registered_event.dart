import 'package:dddart/dddart.dart';

/// Domain event raised when a new user registers in the system.
///
/// This event captures the essential information about a user registration
/// and can be used to trigger side effects like sending welcome emails,
/// creating user profiles, or updating analytics.
class UserRegisteredEvent extends DomainEvent {
  /// The email address of the registered user.
  final String email;

  /// The organization ID the user belongs to.
  final String organizationId;

  /// The user's full name.
  final String fullName;

  /// Creates a new UserRegisteredEvent.
  ///
  /// [userId] identifies the aggregate (user) that raised this event.
  /// [email] is the user's email address.
  /// [organizationId] identifies the organization the user joined.
  /// [fullName] is the user's display name.
  UserRegisteredEvent({
    required UuidValue userId,
    required this.email,
    required this.organizationId,
    required this.fullName,
  }) : super(
          aggregateId: userId,
          context: {
            'organizationId': organizationId,
            'email': email,
          },
        );

  @override
  String toString() {
    return 'UserRegisteredEvent(userId: $aggregateId, email: $email, organization: $organizationId)';
  }
}
