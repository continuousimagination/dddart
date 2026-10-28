/// Test models for DDDart serialization.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';

/// Test AggregateRoot for serialization.
@Serializable()
class TestUser extends UuidAggregateRoot {
  TestUser({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
}

/// Test Value object for serialization.
@Serializable()
class TestAddress extends Value {
  const TestAddress({
    required this.street,
    required this.city,
    required this.zipCode,
  });

  final String street;
  final String city;
  final String zipCode;

  @override
  List<Object?> get props => [street, city, zipCode];
}

/// Test AggregateRoot with nested Value.
@Serializable()
class TestUserWithAddress extends UuidAggregateRoot {
  TestUserWithAddress({
    required this.name,
    required this.email,
    required this.address,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final String email;
  final TestAddress address;
}

/// Test AggregateRoot with snake_case field naming.
@Serializable()
class TestUserSnakeCase extends UuidAggregateRoot {
  TestUserSnakeCase({
    required this.firstName,
    required this.lastName,
    required this.emailAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String firstName;
  final String lastName;
  final String emailAddress;
}

/// Test AggregateRoot with kebab-case field naming.
@Serializable()
class TestUserKebabCase extends UuidAggregateRoot {
  TestUserKebabCase({
    required this.firstName,
    required this.lastName,
    required this.emailAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String firstName;
  final String lastName;
  final String emailAddress;
}

/// Test Value with special types for standardization.
@Serializable()
class TestValueWithSpecialTypes extends Value {
  const TestValueWithSpecialTypes({
    required this.id,
    required this.timestamp,
    required this.name,
  });

  final UuidValue id;
  final DateTime timestamp;
  final String name;

  @override
  List<Object?> get props => [id, timestamp, name];
}

/// Complex nested Value for testing.
@Serializable()
class TestContactInfo extends Value {
  const TestContactInfo({
    required this.email,
    required this.phone,
    required this.address,
  });

  final String email;
  final String phone;
  final TestAddress address;

  @override
  List<Object?> get props => [email, phone, address];
}

/// Test Entity for nested serialization within AggregateRoots.
class TestProfile extends UuidEntity {
  TestProfile({
    required this.bio,
    required this.preferences,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String bio;
  final Map<String, String> preferences;
}

/// Complex AggregateRoot with multiple nested entities and values.
@Serializable()
class TestComplexUser extends UuidAggregateRoot {
  TestComplexUser({
    required this.name,
    required this.contactInfo,
    required this.addresses,
    required this.tags,
    required this.metadata,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final TestContactInfo contactInfo;
  final List<TestAddress> addresses;
  final Set<String> tags;
  final Map<String, dynamic> metadata;
}

/// AggregateRoot with collections of different types.
@Serializable()
class TestProject extends UuidAggregateRoot {
  TestProject({
    required this.title,
    required this.description,
    required this.collaborators,
    required this.milestones,
    required this.settings,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String title;
  final String description;
  final List<TestUser> collaborators;
  final Set<TestValueWithSpecialTypes> milestones;
  final Map<String, TestAddress> settings;
}

/// Deeply nested Value object.
@Serializable()
class TestNestedValue extends Value {
  const TestNestedValue({
    required this.level,
    required this.data,
    required this.child,
  });

  final int level;
  final String data;
  final TestNestedValue? child;

  @override
  List<Object?> get props => [level, data, child];
}

/// Enum for game state.
enum GameState {
  waitingForPlayers,
  inProgress,
  completed,
  stalemate,
}

/// Test AggregateRoot with enum field.
@Serializable()
class TestGame extends UuidAggregateRoot {
  TestGame({
    required this.state,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final GameState state;
}

/// Enum for player role.
enum PlayerRole {
  admin,
  moderator,
  player,
  guest,
}

/// Enum for player status.
enum PlayerStatus {
  active,
  inactive,
  banned,
}

/// Test Value with enum fields (both required and nullable).
@Serializable()
class TestPlayer extends Value {
  const TestPlayer({
    required this.name,
    required this.role,
    this.status,
  });

  final String name;
  final PlayerRole role;
  final PlayerStatus? status;

  @override
  List<Object?> get props => [name, role, status];
}

/// A native identity whose debug representation is deliberately not its key.
class TestNativeIdentity extends Identity {
  const TestNativeIdentity(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
  @override
  String toString() => 'debug-only identity';
}

/// A repository-scoped identity with a numeric native component.
class TestScopedIdentity extends Identity {
  const TestScopedIdentity(this.repository, this.number);
  final String repository;
  final int number;
  @override
  List<Object?> get props => [repository, number];
}

/// Generic application state must be substituted in the concrete consumer.
abstract class IdentityStateBase<I extends Identity> extends AggregateRoot<I> {
  IdentityStateBase({
    required super.id,
    required this.reference,
    super.createdAt,
    super.updatedAt,
  });
  final I reference;
}

/// A nested value that needs the same injected identity registry.
@Serializable()
class TestIdentityHolder extends Value {
  const TestIdentityHolder({required this.identity});
  final TestNativeIdentity identity;
  @override
  List<Object?> get props => [identity];
}

/// A generated consumer covering custom identity fields and collections.
@Serializable()
class TestNativeIdentityAggregate
    extends IdentityStateBase<TestNativeIdentity> {
  TestNativeIdentityAggregate({
    required super.id,
    required super.reference,
    required this.child,
    this.optionalIdentity,
    this.history = const [],
    this.identities = const {},
    this.byName = const {},
    this.byIdentity = const {},
    this.nested = const [],
    super.createdAt,
    super.updatedAt,
  });

  final TestIdentityHolder child;
  final TestNativeIdentity? optionalIdentity;
  final List<TestNativeIdentity?> history;
  final Set<TestNativeIdentity> identities;
  final Map<String, TestNativeIdentity?> byName;
  final Map<TestNativeIdentity, String> byIdentity;
  final List<List<TestNativeIdentity?>> nested;
}

/// A generated consumer whose aggregate identity has structural JSON.
@Serializable()
class TestScopedIdentityAggregate extends AggregateRoot<TestScopedIdentity> {
  TestScopedIdentityAggregate({
    required super.id,
    required this.label,
    super.createdAt,
    super.updatedAt,
  });
  final String label;
}
