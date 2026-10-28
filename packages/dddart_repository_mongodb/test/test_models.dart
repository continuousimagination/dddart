/// Test models and utilities for MongoDB repository testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:mongo_dart/mongo_dart.dart';

part 'test_models.g.dart';
part 'test_models_impl.dart';

/// Simple test aggregate for basic CRUD testing.
@Serializable()
@GenerateMongoRepository(collectionName: 'test_users')
class TestUser extends UuidAggregateRoot {
  /// Creates a test user.
  TestUser({
    required this.name,
    required this.email,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's name.
  final String name;

  /// User's email address.
  final String email;
}

/// Test aggregate with custom collection name.
@Serializable()
@GenerateMongoRepository(collectionName: 'custom_products')
class TestProduct extends UuidAggregateRoot {
  /// Creates a test product.
  TestProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Product name.
  final String name;

  /// Product price.
  final double price;
}

/// Custom repository interface for testing abstract base class generation.
abstract interface class TestOrderRepository
    implements Repository<TestOrder, UuidValue> {
  /// Finds orders by customer ID.
  Future<List<TestOrder>> findByCustomerId(String customerId);

  /// Finds an order by order number.
  Future<TestOrder?> findByOrderNumber(String orderNumber);
}

/// Test aggregate with custom repository interface.
@Serializable()
@GenerateMongoRepository(
  collectionName: 'test_orders',
  implements: TestOrderRepository,
)
class TestOrder extends UuidAggregateRoot {
  /// Creates a test order.
  TestOrder({
    required this.orderNumber,
    required this.customerId,
    required this.total,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Order number.
  final String orderNumber;

  /// Customer ID.
  final String customerId;

  /// Order total.
  final double total;
}

/// Test aggregate for SerializationConfig testing.
@Serializable()
@GenerateMongoRepository(collectionName: 'test_accounts')
class TestAccount extends UuidAggregateRoot {
  /// Creates a test account.
  TestAccount({
    required this.accountName,
    required this.accountType,
    required this.balance,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Account name.
  final String accountName;

  /// Account type.
  final String accountType;

  /// Account balance.
  final double balance;
}

/// Application native identity whose debug display is not its key.
class NativeId extends Identity {
  /// Creates a native identity.
  const NativeId(this.value);

  /// The externally assigned text.
  final String value;
  @override
  List<Object?> get props => [value];
  @override
  String toString() => 'debug identity';
}

/// Application scope and local number jointly define identity.
class ScopedId extends Identity {
  /// Creates a scoped identity.
  const ScopedId(this.scope, this.number);

  /// Repository scope.
  final String scope;

  /// Native local number.
  final int number;
  @override
  List<Object?> get props => [scope, number];
}

/// Native identity wire/key contract.
class NativeIdCodec implements IdentityCodec<NativeId> {
  /// Creates the codec.
  const NativeIdCodec();
  @override
  String toJson(NativeId id) => id.value;
  @override
  NativeId fromJson(Object? value) {
    if (value is! String) throw const FormatException('Expected native string');
    return NativeId(value);
  }

  @override
  String toKey(NativeId id) => id.value;
  @override
  NativeId fromKey(String value) => NativeId(value);
}

/// Scoped identity wire/key contract.
class ScopedIdCodec implements IdentityCodec<ScopedId> {
  /// Creates the codec.
  const ScopedIdCodec();
  @override
  Object toJson(ScopedId id) => {'scope': id.scope, 'number': id.number};
  @override
  ScopedId fromJson(Object? value) {
    if (value is! Map || value['scope'] is! String || value['number'] is! int) {
      throw const FormatException('Expected scoped identity');
    }
    return ScopedId(value['scope'] as String, value['number'] as int);
  }

  @override
  String toKey(ScopedId id) => jsonEncode([id.scope, id.number]);
  @override
  ScopedId fromKey(String value) {
    final tuple = jsonDecode(value) as List<dynamic>;
    if (tuple.length != 2) throw const FormatException('Expected scope tuple');
    return fromJson({'scope': tuple[0], 'number': tuple[1]});
  }
}

/// Shared application state exercises resolved inherited identity arguments.
abstract class IssueBase<I extends Identity> extends AggregateRoot<I> {
  /// Creates an externally identified issue.
  IssueBase({
    required super.id,
    required this.label,
    super.createdAt,
    super.updatedAt,
  });

  /// A queryable application field.
  final String label;
}

/// A native-ID aggregate for persistence tests.
@Serializable()
@GenerateMongoRepository(collectionName: 'worky_native_identities')
class NativeIssue extends IssueBase<NativeId> {
  /// Creates the issue.
  NativeIssue({
    required super.id,
    required super.label,
    super.createdAt,
    super.updatedAt,
  });
}

/// A domain read with a named argument to preserve in generated signatures.
// ignore: one_member_abstracts
abstract interface class ScopedReads<T, I> {
  /// Looks up a specific scoped ID with an optional label check.
  Future<T?> findScoped(I id, {String? label});
}

/// Domain-specific repository; enumeration remains opt-in.
abstract interface class ScopedIssueRepository
    implements
        Repository<ScopedIssue, ScopedId>,
        ScopedReads<ScopedIssue, ScopedId> {}

/// A scoped-ID aggregate with a custom generated repository interface.
@Serializable()
@GenerateMongoRepository(
  collectionName: 'worky_scoped_identities',
  implements: ScopedIssueRepository,
)
class ScopedIssue extends IssueBase<ScopedId> {
  /// Creates the issue.
  ScopedIssue({
    required super.id,
    required super.label,
    super.createdAt,
    super.updatedAt,
  });
}

/// New registry per composition; no global mutable registration.
IdentityCodecRegistry identityCodecs() => IdentityCodecRegistry()
  ..register<NativeId>('native.v1', const NativeIdCodec())
  ..register<ScopedId>('scoped.v1', const ScopedIdCodec());
