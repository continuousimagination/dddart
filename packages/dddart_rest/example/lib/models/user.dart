import 'package:dddart/dddart.dart';
import 'address.dart';
import 'profile.dart';

/// Example aggregate root representing a User with child entities and value objects
///
/// AGGREGATE ROOT PATTERN:
/// An aggregate root is the entry point to an aggregate - a cluster of domain objects
/// that can be treated as a single unit. The aggregate root ensures consistency of
/// changes being made within the aggregate boundary.
///
/// This User aggregate demonstrates:
///
/// 1. AGGREGATE ROOT (User):
///    - Extends AggregateRoot from dddart package
///    - Has a unique identifier (id) inherited from AggregateRoot
///    - Controls access to all objects within the aggregate
///    - Ensures invariants are maintained across the aggregate
///
/// 2. CHILD ENTITY (Profile):
///    - An entity within the aggregate that has its own identity
///    - Can only be accessed through the aggregate root
///    - Lifecycle is managed by the aggregate root
///    - Optional in this example (user may not have a profile)
///
/// 3. VALUE OBJECT (Address):
///    - Immutable object defined by its attributes, not identity
///    - Two addresses with same values are considered equal
///    - Cannot exist independently - always part of an entity
///    - Required in this example (every user must have an address)
///
/// AGGREGATE BOUNDARIES:
/// The User aggregate boundary includes:
/// - User (root) + Address (value object) + Profile (child entity)
/// - All changes to Profile or Address must go through User
/// - Repository operations work on the entire aggregate, not individual parts
class User extends AggregateRoot {
  /// Creates a User with the specified properties
  ///
  /// The constructor enforces required fields (firstName, lastName, email, address)
  /// while allowing optional fields (profile). The id, createdAt, and updatedAt
  /// are inherited from AggregateRoot and managed by the framework.
  User({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    this.profile,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's first name (primitive property)
  final String firstName;

  /// User's last name (primitive property)
  final String lastName;

  /// User's email address (primitive property, business key)
  /// In a real application, this might be a value object with validation
  final String email;

  /// User's physical address (VALUE OBJECT)
  ///
  /// Address is a value object because:
  /// - It's immutable (all fields are final)
  /// - It's defined by its attributes, not an identity
  /// - Two addresses with same values are considered equal
  /// - It cannot exist independently of the User
  final Address address;

  /// Optional user profile (CHILD ENTITY)
  ///
  /// Profile is a child entity because:
  /// - It has its own identity (id field)
  /// - It has a lifecycle (createdAt, updatedAt)
  /// - It's optional - not all users have profiles
  /// - It can only be accessed through the User aggregate root
  /// - Changes to Profile are part of the User aggregate transaction
  final Profile? profile;

  /// Creates a copy of this User with the specified fields replaced
  User copyWith({
    String? firstName,
    String? lastName,
    String? email,
    Address? address,
    Profile? profile,
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      address: address ?? this.address,
      profile: profile ?? this.profile,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
