/// Test models for SQLite repository property-based testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'test_models.g.dart';

/// Value object representing money with amount and currency.
@Serializable()
class Money extends Value {
  /// Creates a money value object.
  const Money({
    required this.amount,
    required this.currency,
  });

  /// The monetary amount.
  final double amount;

  /// The currency code (e.g., 'USD', 'EUR').
  final String currency;

  @override
  List<Object?> get props => [amount, currency];
}

/// Value object representing an address.
@Serializable()
class Address extends Value {
  /// Creates an address value object.
  const Address({
    required this.street,
    required this.city,
    required this.country,
  });

  /// Street address.
  final String street;

  /// City name.
  final String city;

  /// Country name.
  final String country;

  @override
  List<Object?> get props => [street, city, country];
}

/// Entity representing an order item within an order aggregate.
@Serializable()
class OrderItem extends UuidEntity {
  /// Creates an order item entity.
  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// The product ID.
  final UuidValue productId;

  /// Quantity ordered.
  final int quantity;

  /// Price per item.
  final Money price;
}

/// Aggregate root representing an order with nested entities and value objects.
@Serializable()
@GenerateSqliteRepository(tableName: 'orders')
class Order extends UuidAggregateRoot {
  /// Creates an order aggregate.
  Order({
    required this.customerId,
    required this.totalAmount,
    required this.shippingAddress,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Customer ID (reference to another aggregate).
  final UuidValue customerId;

  /// Total order amount (embedded value object).
  final Money totalAmount;

  /// Shipping address (embedded value object).
  final Address shippingAddress;

  /// Order items (nested entities).
  final List<OrderItem> items;
}

/// Simple aggregate for basic testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_users')
class TestUser extends UuidAggregateRoot {
  /// Creates a test user.
  TestUser({
    required this.name,
    required this.email,
    required this.isActive,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// User's name.
  final String name;

  /// User's email address.
  final String email;

  /// Whether the user is active.
  final bool isActive;
}

/// Aggregate with nullable value object for testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_products')
class TestProduct extends UuidAggregateRoot {
  /// Creates a test product.
  TestProduct({
    required this.name,
    required this.price,
    this.discount,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Product name.
  final String name;

  /// Product price (embedded value object).
  final Money price;

  /// Optional discount (nullable embedded value object).
  final Money? discount;
}

/// Aggregate with primitive collections for testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_primitive_collections')
class TestPrimitiveCollections extends UuidAggregateRoot {
  /// Creates a test aggregate with primitive collections.
  TestPrimitiveCollections({
    required this.name,
    required this.favoriteNumbers,
    required this.tags,
    required this.scoresByGame,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name field.
  final String name;

  /// List of favorite numbers.
  final List<int> favoriteNumbers;

  /// Set of tags.
  final Set<String> tags;

  /// Map of scores by game name.
  final Map<String, int> scoresByGame;
}

/// Aggregate with value object collections for testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_value_collections')
class TestValueCollections extends UuidAggregateRoot {
  /// Creates a test aggregate with value object collections.
  TestValueCollections({
    required this.name,
    required this.payments,
    required this.addresses,
    required this.pricesByProduct,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name field.
  final String name;

  /// List of payments.
  final List<Money> payments;

  /// Set of addresses.
  final Set<Address> addresses;

  /// Map of prices by product name.
  final Map<String, Money> pricesByProduct;
}

/// Simple entity for collection testing.
@Serializable()
class TestItem extends UuidEntity {
  /// Creates a test item entity.
  TestItem({
    required this.name,
    required this.quantity,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Item name.
  final String name;

  /// Item quantity.
  final int quantity;
}

/// Aggregate with entity collections for testing.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_entity_collections')
class TestEntityCollections extends UuidAggregateRoot {
  /// Creates a test aggregate with entity collections.
  TestEntityCollections({
    required this.name,
    required this.uniqueItems,
    required this.itemsByCategory,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name field.
  final String name;

  /// Set of unique items.
  final Set<TestItem> uniqueItems;

  /// Map of items by category.
  final Map<String, TestItem> itemsByCategory;
}

/// Aggregate with nullable collections for testing null handling.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_nullable_collections')
class TestNullableCollections extends UuidAggregateRoot {
  /// Creates a test aggregate with nullable collections.
  TestNullableCollections({
    required this.name,
    this.optionalNumbers,
    this.optionalTags,
    this.optionalScores,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name field.
  final String name;

  /// Optional list of numbers.
  final List<int>? optionalNumbers;

  /// Optional set of tags.
  final Set<String>? optionalTags;

  /// Optional map of scores.
  final Map<String, int>? optionalScores;
}

/// Aggregate with collections containing nullable elements.
@Serializable()
@GenerateSqliteRepository(tableName: 'test_nullable_elements')
class TestNullableElements extends UuidAggregateRoot {
  /// Creates a test aggregate with nullable collection elements.
  TestNullableElements({
    required this.name,
    required this.nullableNumbers,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  /// Name field.
  final String name;

  /// List with nullable integer elements.
  final List<int?> nullableNumbers;
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

/// Generic inherited application state with identity fields and collections.
abstract class SqlIssueBase<I extends Identity, C extends Entity<ScopedId>>
    extends AggregateRoot<I> {
  /// Creates the native or scoped issue state.
  SqlIssueBase({
    required super.id,
    required this.label,
    required this.reference,
    this.optionalReference,
    this.history = const [],
    this.labelsById = const {},
    this.comments = const [],
    super.createdAt,
    super.updatedAt,
  });

  /// Application display state, independent of key encoding.
  final String label;

  /// Another identity of the same concrete kind.
  final I reference;

  /// Optional reference used to verify null updates.
  final I? optionalReference;

  /// Nullable identity elements in inherited collection state.
  final List<I?> history;

  /// Identity map keys use canonical keys, values use structural JSON.
  final Map<I, I?> labelsById;

  /// Entity collection declared generically and closed by the concrete root.
  final List<C> comments;
}

/// Embedded application value containing a structured identity.
@Serializable()
class SqlIdentityHolder extends Value {
  /// Creates the value.
  const SqlIdentityHolder({required this.owner});

  /// Identity JSON must remain one column leaf.
  final ScopedId owner;
  @override
  List<Object?> get props => [owner];
}

/// Child entity managed inside the native issue aggregate.
@Serializable()
class NativeComment extends Entity<ScopedId> {
  /// Creates the child with its own scoped native identity.
  NativeComment({
    required super.id,
    required this.authorId,
    required this.message,
    super.createdAt,
    super.updatedAt,
  });

  /// A different application identity kind.
  final NativeId authorId;

  /// Comment body.
  final String message;
}

/// Child entity managed inside the scoped issue aggregate.
@Serializable()
class ScopedComment extends Entity<ScopedId> {
  /// Creates the child with its own scoped native identity.
  ScopedComment({
    required super.id,
    required this.authorId,
    required this.message,
    super.createdAt,
    super.updatedAt,
  });

  /// A different application identity kind.
  final NativeId authorId;

  /// Comment body.
  final String message;
}

/// Domain-specific interface retains concrete ID and named parameters.
abstract interface class NativeIssueRepository
    implements Repository<NativeIssue, NativeId> {
  /// Looks up the native issue with an optional label check.
  Future<NativeIssue?> lookupLabel(NativeId id, {String? label});
}

/// Native primary keys, embedded identities and entity collections.
@Serializable()
@GenerateSqliteRepository(
  tableName: 'worky_native_issues',
  implements: NativeIssueRepository,
)
class NativeIssue extends SqlIssueBase<NativeId, NativeComment> {
  /// Creates a native issue.
  NativeIssue({
    required super.id,
    required super.label,
    required super.reference,
    super.optionalReference,
    super.history,
    super.labelsById,
    this.holder,
    super.comments,
    super.createdAt,
    super.updatedAt,
  });

  /// Optional embedded identity.
  final SqlIdentityHolder? holder;
}

/// Scoped primary/foreign keys and collection parents.
@Serializable()
@GenerateSqliteRepository(tableName: 'worky_scoped_issues')
class ScopedIssue extends SqlIssueBase<ScopedId, ScopedComment> {
  /// Creates a scoped issue.
  ScopedIssue({
    required super.id,
    required super.label,
    required super.reference,
    super.optionalReference,
    super.history,
    super.labelsById,
    this.holder,
    super.comments,
    super.createdAt,
    super.updatedAt,
  });

  /// Optional embedded identity.
  final SqlIdentityHolder? holder;
}

/// Application composition uses one fresh registry, shared with serializers.
IdentityCodecRegistry identityCodecs() => IdentityCodecRegistry()
  ..register<NativeId>('native.v1', const NativeIdCodec())
  ..register<ScopedId>('scoped.v1', const ScopedIdCodec());

/// Concrete custom interface implementation preserves typed lookups.
class NativeIssueSqliteRepositoryImpl extends NativeIssueSqliteRepositoryBase {
  /// Creates the repository with application codecs.
  NativeIssueSqliteRepositoryImpl(super.connection, {super.identityCodecs});
  @override
  Future<NativeIssue?> lookupLabel(NativeId id, {String? label}) async {
    try {
      final issue = await getById(id);
      return label == null || issue.label == label ? issue : null;
    } on RepositoryException catch (error) {
      if (error.type == RepositoryExceptionType.notFound) return null;
      rethrow;
    }
  }
}
