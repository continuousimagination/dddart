import 'package:dddart/dddart.dart';

/// Child entity representing a user's profile information
///
/// ENTITY PATTERN (CHILD ENTITY):
/// An entity is an object that has a unique identity and a lifecycle.
/// Unlike value objects, entities are defined by their identity, not their attributes.
/// Two entities with the same attributes but different IDs are different entities.
///
/// This Profile is a CHILD ENTITY within the User aggregate:
///
/// 1. HAS IDENTITY:
///    - Extends Entity from dddart, which provides an 'id' field
///    - The id uniquely identifies this specific profile
///    - Two profiles with same bio/avatarUrl but different IDs are different
///
/// 2. HAS LIFECYCLE:
///    - Has createdAt and updatedAt timestamps (inherited from Entity)
///    - Can be created, modified, and deleted
///    - Lifecycle is managed by the User aggregate root
///
/// 3. PART OF AGGREGATE:
///    - Cannot exist independently - always belongs to a User
///    - Can only be accessed through the User aggregate root
///    - Changes to Profile are part of the User aggregate's transaction boundary
///    - When User is saved, Profile is saved with it
///    - When User is deleted, Profile is deleted with it
///
/// 4. MUTABLE ATTRIBUTES:
///    - While the Profile object itself is immutable (final fields)
///    - The User can replace the entire Profile with a new one (copyWith pattern)
///    - This maintains immutability while allowing updates
///
/// CHILD ENTITY vs ROOT ENTITY:
/// - Root entities (AggregateRoot) can be directly accessed via Repository
/// - Child entities can only be accessed through their aggregate root
/// - Profile is a child entity - you get it through User, not directly
///
/// WHEN TO USE CHILD ENTITIES:
/// - When an object has identity and lifecycle
/// - When it logically belongs to a parent aggregate
/// - When it should be persisted/retrieved with the parent
/// - Examples: OrderLineItem (in Order), Comment (in BlogPost), Address (in Customer)
class Profile extends Entity {
  /// Creates a Profile with the specified properties
  ///
  /// The id, createdAt, and updatedAt are inherited from Entity and managed
  /// by the framework. When creating a new Profile, these can be omitted and
  /// will be auto-generated. When deserializing from storage, they are provided.
  Profile({
    required this.bio,
    required this.avatarUrl,
    required this.phoneNumber,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's biography or description
  /// In a production system, this might have length limits or formatting rules
  final String bio;

  /// URL to user's avatar image
  /// In a production system, this would be validated as a proper URL
  final String avatarUrl;

  /// User's phone number
  /// In a production system, this might be a PhoneNumber value object with validation
  final String phoneNumber;

  /// Creates a copy of this Profile with the specified fields replaced
  Profile copyWith({
    String? bio,
    String? avatarUrl,
    String? phoneNumber,
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
