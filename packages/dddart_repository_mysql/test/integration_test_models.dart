/// Domain models for integration testing.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_mysql/dddart_repository_mysql.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'integration_test_models.g.dart';

/// A migration probe whose table is deliberately provisioned with the old type.
@Serializable()
@GenerateMysqlRepository(tableName: 'worky_legacy_identity')
class LegacyIdentity extends UuidAggregateRoot {
  /// Creates the migration probe.
  LegacyIdentity({super.id, super.createdAt, super.updatedAt});
}

// ============================================================================
// Simple Product - Basic CRUD Testing
// ============================================================================

/// Simple product aggregate for basic CRUD testing.
@Serializable()
@GenerateMysqlRepository()
class SimpleProduct extends UuidAggregateRoot {
  SimpleProduct({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final double price;
}

// ============================================================================
// Order with Items - Entity Collection Testing
// ============================================================================

/// Order aggregate with entity collection for testing object graphs.
@Serializable()
@GenerateMysqlRepository(tableName: 'orders')
class Order extends UuidAggregateRoot {
  Order({
    required this.customerName,
    required this.items,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String customerName;
  final List<OrderItem> items;
}

/// Order item entity for testing entity relationships.
@Serializable()
class OrderItem extends UuidEntity {
  OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
}

// ============================================================================
// Customer with Address - Value Object Testing
// ============================================================================

/// Customer aggregate for testing value object embedding.
@Serializable()
@GenerateMysqlRepository()
class Customer extends UuidAggregateRoot {
  Customer({
    required this.name,
    required this.email,
    required this.shippingAddress,
    this.billingAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final Email email;
  final Address shippingAddress;
  final Address? billingAddress;
}

/// Email value object.
@Serializable()
class Email extends Value {
  const Email({required this.value});

  final String value;

  @override
  List<Object?> get props => [value];
}

/// Address value object for testing embedding.
@Serializable()
class Address extends Value {
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  final String street;
  final String city;
  final String state;
  final String zipCode;

  @override
  List<Object?> get props => [street, city, state, zipCode];
}

// ============================================================================
// Product with Custom Repository - Custom Methods Testing
// ============================================================================

/// Product aggregate for custom repository testing.
@Serializable()
@GenerateMysqlRepository(implements: CustomProductRepository)
class Product extends UuidAggregateRoot {
  Product({
    required this.name,
    required this.price,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String name;
  final double price;
}

/// Custom repository interface for testing custom methods.
abstract class CustomProductRepository
    implements Repository<Product, UuidValue> {
  Future<List<Product>> findByMinPrice(double minPrice);
  Future<int> countProducts();
}

/// Implementation of custom repository.
class CustomProductRepositoryImpl extends ProductMysqlRepositoryBase
    implements CustomProductRepository {
  CustomProductRepositoryImpl(super.connection);

  @override
  Future<List<Product>> findByMinPrice(double minPrice) async {
    final rows = await _connection.query(
      'SELECT id, name, price, createdAt, updatedAt '
      'FROM product WHERE price >= ?',
      [minPrice],
    );

    return rows.map((row) {
      final json = _rowToJson(row);
      return _serializer.fromJson(json);
    }).toList();
  }

  @override
  Future<int> countProducts() async {
    final result = await _connection.query(
      'SELECT COUNT(*) as count FROM product',
    );

    return result.first['count']! as int;
  }
}

// ============================================================================
// Collection Testing Models
// ============================================================================

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

/// Aggregate with primitive collections for testing.
@Serializable()
@GenerateMysqlRepository(tableName: 'test_primitive_collections')
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
@GenerateMysqlRepository(tableName: 'test_value_collections')
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

// Note: Entity collections are not yet fully supported in MySQL
// Commenting out for now until implementation is complete
//
// /// Simple entity for collection testing.
// @Serializable()
// class TestItem extends UuidEntity {
//   /// Creates a test item entity.
//   TestItem({
//     required this.name,
//     required this.quantity,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   /// Item name.
//   final String name;
//
//   /// Item quantity.
//   final int quantity;
// }
//
// /// Aggregate with entity collections for testing.
// @Serializable()
// @GenerateMysqlRepository(tableName: 'test_entity_collections')
// class TestEntityCollections extends UuidAggregateRoot {
//   /// Creates a test aggregate with entity collections.
//   TestEntityCollections({
//     required this.name,
//     required this.uniqueItems,
//     required this.itemsByCategory,
//     super.id,
//     super.createdAt,
//     super.updatedAt,
//   });
//
//   /// Name field.
//   final String name;
//
//   /// Set of unique items.
//   final Set<TestItem> uniqueItems;
//
//   /// Map of items by category.
//   final Map<String, TestItem> itemsByCategory;
// }

/// Aggregate with nullable collections for testing null handling.
@Serializable()
@GenerateMysqlRepository(tableName: 'test_nullable_collections')
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
@GenerateMysqlRepository(
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
@GenerateMysqlRepository(tableName: 'worky_scoped_issues')
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
class NativeIssueMysqlRepositoryImpl extends NativeIssueMysqlRepositoryBase {
  /// Creates the repository with application codecs.
  NativeIssueMysqlRepositoryImpl(super.connection, {super.identityCodecs});
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
