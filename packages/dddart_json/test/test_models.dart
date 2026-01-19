/// Test models for DDDart serialization.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';

/// Test AggregateRoot for serialization.
@Serializable()
class TestUser extends AggregateRoot {
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
class TestUserWithAddress extends AggregateRoot {
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
class TestUserSnakeCase extends AggregateRoot {
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
class TestUserKebabCase extends AggregateRoot {
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
class TestProfile extends Entity {
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
class TestComplexUser extends AggregateRoot {
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
class TestProject extends AggregateRoot {
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
class TestGame extends AggregateRoot {
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
