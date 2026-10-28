/// Test models and utilities for REST repository testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';
part 'test_models_impl.dart';

/// Simple test aggregate for basic CRUD testing.
@Serializable()
@GenerateRestRepository(resourcePath: '/users')
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

/// Test aggregate with custom resource path.
@Serializable()
@GenerateRestRepository(resourcePath: '/products')
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
@GenerateRestRepository(
  resourcePath: '/orders',
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

/// Test aggregate for additional testing scenarios.
@Serializable()
@GenerateRestRepository(resourcePath: '/accounts')
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

/// Test aggregate that relies on the inferred REST resource path.
@Serializable()
@GenerateRestRepository()
class InferredResource extends UuidAggregateRoot {
  /// Creates an inferred-resource test aggregate.
  InferredResource({
    required this.name,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Resource name.
  final String name;
}

/// Externally assigned case-sensitive issue identifier.
class NativeId extends Identity {
  /// Keeps the remote identifier exactly as supplied.
  const NativeId(this.value);

  /// Native opaque value.
  final String value;
  @override
  List<Object?> get props => [value];
}

/// Native identity codec; empty keys are invalid.
class NativeIdCodec implements IdentityCodec<NativeId> {
  /// Creates a native codec.
  const NativeIdCodec();
  @override
  String toJson(NativeId identity) => identity.value;
  @override
  NativeId fromJson(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Expected nonempty native ID');
    }
    return NativeId(value);
  }

  @override
  String toKey(NativeId identity) => identity.value;
  @override
  NativeId fromKey(String value) => fromJson(value);
}

/// Repository-scoped issue number.
class ScopedId extends Identity {
  /// Creates a scoped identity.
  const ScopedId(this.repository, this.number);

  /// Full case-sensitive repository identifier.
  final String repository;

  /// Repository-local issue number.
  final int number;
  @override
  List<Object?> get props => [repository, number];
}

/// Structural JSON and an unambiguous canonical tuple key.
class ScopedIdCodec implements IdentityCodec<ScopedId> {
  /// Creates a scoped codec.
  const ScopedIdCodec();
  @override
  Map<String, Object> toJson(ScopedId identity) => {
        'repository': identity.repository,
        'number': identity.number,
      };
  @override
  ScopedId fromJson(Object? value) {
    if (value is! Map ||
        value['repository'] is! String ||
        (value['repository'] as String).isEmpty ||
        value['number'] is! int ||
        (value['number'] as int) <= 0) {
      throw const FormatException('Expected scoped ID');
    }
    return ScopedId(value['repository'] as String, value['number'] as int);
  }

  @override
  String toKey(ScopedId identity) =>
      jsonEncode([identity.repository, identity.number]);
  @override
  ScopedId fromKey(String value) {
    final tuple = jsonDecode(value) as List<dynamic>;
    if (tuple.length != 2) throw const FormatException('Expected pair');
    return fromJson({'repository': tuple[0], 'number': tuple[1]});
  }
}

/// Test-local codecs, never global state.
IdentityCodecRegistry issueIdentityCodecs() => IdentityCodecRegistry()
  ..register<NativeId>('native-issue', const NativeIdCodec())
  ..register<ScopedId>('scoped-issue', const ScopedIdCodec());

/// Generic parent ensures generators resolve instantiated identity types.
abstract class IssueBase<I extends Identity> extends AggregateRoot<I> {
  /// Creates an issue.
  IssueBase({
    required super.id,
    required this.title,
    super.createdAt,
    super.updatedAt,
  });

  /// Issue title.
  final String title;
}

/// Additional operations retain their named parameters and overridden signature.
abstract interface class NativeReadRepository
    implements Repository<NativeIssue, NativeId> {
  /// Reads with a label.
  Future<NativeIssue> lookup(NativeId id, {String label = 'default'});
}

/// Refined interface exercises duplicate inherited methods.
abstract interface class NativeIssueRepository implements NativeReadRepository {
  @override
  Future<NativeIssue> lookup(NativeId id, {String label = 'default'});
}

/// Native identity REST aggregate.
@Serializable()
@GenerateRestRepository(
  resourcePath: '/native-issues',
  implements: NativeIssueRepository,
)
class NativeIssue extends IssueBase<NativeId> {
  /// Creates a native issue.
  NativeIssue({
    required super.id,
    required super.title,
    super.createdAt,
    super.updatedAt,
  });
}

/// Scoped identity REST aggregate.
@Serializable()
@GenerateRestRepository(resourcePath: '/scoped-issues')
class ScopedIssue extends IssueBase<ScopedId> {
  /// Creates a scoped issue.
  ScopedIssue({
    required super.id,
    required super.title,
    super.createdAt,
    super.updatedAt,
  });
}

/// Concrete custom interface consumer, independent of private generated members.
class NativeIssueRestRepository extends NativeIssueRestRepositoryBase {
  /// Injects the same codecs into key and body serialization.
  NativeIssueRestRepository(super.connection, {super.identityCodecs});
  @override
  Future<NativeIssue> lookup(NativeId id, {String label = 'default'}) =>
      getById(id);
}
