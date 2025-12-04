// ignore_for_file: avoid_print

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_sqlite/dddart_repository_sqlite.dart';

part 'collection_examples.g.dart';

// ============================================================================
// Example 1: Primitive Collections
// ============================================================================

/// User aggregate with primitive collections
@Serializable()
@GenerateSqliteRepository()
class User extends AggregateRoot {
  User({
    required UuidValue id,
    required this.name,
    required this.favoriteNumbers,
    required this.tags,
    required this.scoresByGame,
    required this.loginDates,
  }) : super(id);

  final String name;
  final List<int> favoriteNumbers; // Ordered list of integers
  final Set<String> tags; // Unique set of strings
  final Map<String, int> scoresByGame; // Key-value map
  final List<DateTime> loginDates; // List of DateTime values
}

Future<void> primitiveCollectionsExample() async {
  print('\n=== Primitive Collections Example ===\n');

  final connection = SqliteConnection.memory();
  await connection.open();

  final repository = UserSqliteRepository(connection);
  await repository.createTables();

  // Create user with primitive collections
  final user = User(
    id: UuidValue.generate(),
    name: 'Alice',
    favoriteNumbers: [7, 13, 42, 99],
    tags: {'developer', 'dart', 'ddd', 'flutter'},
    scoresByGame: {
      'chess': 1200,
      'go': 1500,
      'poker': 850,
    },
    loginDates: [
      DateTime(2024, 1, 1),
      DateTime(2024, 6, 15),
      DateTime(2024, 12, 4),
    ],
  );

  print('Saving user with collections...');
  await repository.save(user);

  print('Loading user...');
  final loaded = await repository.getById(user.id);

  print('Name: ${loaded.name}');
  print('Favorite numbers: ${loaded.favoriteNumbers}'); // Order preserved
  print('Tags: ${loaded.tags}'); // Unique values
  print('Scores: ${loaded.scoresByGame}');
  print('Login dates: ${loaded.loginDates}');

  // Update collections
  print('\nUpdating collections...');
  final updated = User(
    id: loaded.id,
    name: loaded.name,
    favoriteNumbers: [7, 13, 42, 99, 100], // Added new number
    tags: {'developer', 'dart', 'ddd'}, // Removed 'flutter'
    scoresByGame: {
      'chess': 1250, // Updated score
      'go': 1500,
      'scrabble': 950, // New game
    },
    loginDates: [
      ...loaded.loginDates,
      DateTime(2024, 12, 5), // New login
    ],
  );

  await repository.save(updated);
  final reloaded = await repository.getById(user.id);
  print('Updated favorite numbers: ${reloaded.favoriteNumbers}');
  print('Updated tags: ${reloaded.tags}');
  print('Updated scores: ${reloaded.scoresByGame}');

  await connection.close();
  print('\n✓ Primitive collections example completed');
}

// ============================================================================
// Example 2: Value Object Collections
// ============================================================================

@Serializable()
class Money {
  Money({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  String toString() => '$amount $currency';
}

@Serializable()
class Address {
  Address({
    required this.street,
    required this.city,
    required this.country,
  });

  final String street;
  final String city;
  final String country;

  @override
  String toString() => '$street, $city, $country';
}

@Serializable()
class Color {
  Color({required this.name, required this.hex});

  final String name;
  final String hex;

  @override
  String toString() => '$name ($hex)';
}

/// Order aggregate with value object collections
@Serializable()
@GenerateSqliteRepository()
class Order extends AggregateRoot {
  Order({
    required UuidValue id,
    required this.orderNumber,
    required this.payments,
    required this.deliveryLocations,
    required this.discountsByCode,
  }) : super(id);

  final String orderNumber;
  final List<Money> payments; // Ordered payments
  final Set<Address> deliveryLocations; // Unique addresses
  final Map<String, Money> discountsByCode; // Discounts by code
}

Future<void> valueObjectCollectionsExample() async {
  print('\n=== Value Object Collections Example ===\n');

  final connection = SqliteConnection.memory();
  await connection.open();

  final repository = OrderSqliteRepository(connection);
  await repository.createTables();

  // Create order with value object collections
  final order = Order(
    id: UuidValue.generate(),
    orderNumber: 'ORD-2024-001',
    payments: [
      Money(amount: 50.0, currency: 'USD'),
      Money(amount: 49.99, currency: 'USD'),
      Money(amount: 10.0, currency: 'USD'),
    ],
    deliveryLocations: {
      Address(street: '123 Main St', city: 'New York', country: 'USA'),
      Address(street: '456 Oak Ave', city: 'Los Angeles', country: 'USA'),
    },
    discountsByCode: {
      'SAVE10': Money(amount: 10.0, currency: 'USD'),
      'SAVE20': Money(amount: 20.0, currency: 'USD'),
      'FREESHIP': Money(amount: 5.99, currency: 'USD'),
    },
  );

  print('Saving order with value object collections...');
  await repository.save(order);

  print('Loading order...');
  final loaded = await repository.getById(order.id);

  print('Order number: ${loaded.orderNumber}');
  print('Payments (ordered):');
  for (var i = 0; i < loaded.payments.length; i++) {
    print('  ${i + 1}. ${loaded.payments[i]}');
  }

  print('Delivery locations (unique):');
  for (final location in loaded.deliveryLocations) {
    print('  - $location');
  }

  print('Discounts by code:');
  loaded.discountsByCode.forEach((code, discount) {
    print('  $code: $discount');
  });

  await connection.close();
  print('\n✓ Value object collections example completed');
}

// ============================================================================
// Example 3: Entity Collections
// ============================================================================

@Serializable()
class CartItem extends Entity {
  CartItem({
    required UuidValue id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  }) : super(id);

  final UuidValue productId;
  final String productName;
  final int quantity;
  final Money price;

  @override
  String toString() => '$productName x$quantity @ $price';
}

@Serializable()
class Discount extends Entity {
  Discount({
    required UuidValue id,
    required this.code,
    required this.percentage,
    required this.description,
  }) : super(id);

  final String code;
  final double percentage;
  final String description;

  @override
  String toString() => '$code: $percentage% - $description';
}

/// Shopping cart aggregate with entity collections
@Serializable()
@GenerateSqliteRepository()
class ShoppingCart extends AggregateRoot {
  ShoppingCart({
    required UuidValue id,
    required this.userId,
    required this.items,
    required this.appliedDiscounts,
    required this.savedItems,
  }) : super(id);

  final UuidValue userId;
  final List<CartItem> items; // Ordered items (existing support)
  final Set<Discount> appliedDiscounts; // Unique discounts
  final Map<String, CartItem> savedItems; // Named saved items
}

Future<void> entityCollectionsExample() async {
  print('\n=== Entity Collections Example ===\n');

  final connection = SqliteConnection.memory();
  await connection.open();

  final repository = ShoppingCartSqliteRepository(connection);
  await repository.createTables();

  // Create shopping cart with entity collections
  final cart = ShoppingCart(
    id: UuidValue.generate(),
    userId: UuidValue.generate(),
    items: [
      CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Dart Programming Book',
        quantity: 2,
        price: Money(amount: 29.99, currency: 'USD'),
      ),
      CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Flutter Toolkit',
        quantity: 1,
        price: Money(amount: 49.99, currency: 'USD'),
      ),
    ],
    appliedDiscounts: {
      Discount(
        id: UuidValue.generate(),
        code: 'SAVE10',
        percentage: 10.0,
        description: '10% off entire order',
      ),
      Discount(
        id: UuidValue.generate(),
        code: 'FREESHIP',
        percentage: 0.0,
        description: 'Free shipping',
      ),
    },
    savedItems: {
      'wishlist': CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Advanced DDD Course',
        quantity: 1,
        price: Money(amount: 99.99, currency: 'USD'),
      ),
      'later': CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Microservices Guide',
        quantity: 1,
        price: Money(amount: 39.99, currency: 'USD'),
      ),
    },
  );

  print('Saving shopping cart with entity collections...');
  await repository.save(cart);

  print('Loading shopping cart...');
  final loaded = await repository.getById(cart.id);

  print('Cart items (ordered):');
  for (var i = 0; i < loaded.items.length; i++) {
    print('  ${i + 1}. ${loaded.items[i]}');
  }

  print('Applied discounts (unique):');
  for (final discount in loaded.appliedDiscounts) {
    print('  - $discount');
  }

  print('Saved items (by name):');
  loaded.savedItems.forEach((name, item) {
    print('  $name: $item');
  });

  await connection.close();
  print('\n✓ Entity collections example completed');
}

// ============================================================================
// Example 4: Nullable Collections and Empty Collections
// ============================================================================

@Serializable()
@GenerateSqliteRepository()
class Product extends AggregateRoot {
  Product({
    required UuidValue id,
    required this.name,
    this.optionalTags,
    required this.reviews,
    required this.nullableRatings,
  }) : super(id);

  final String name;
  final Set<String>? optionalTags; // Nullable collection
  final List<String> reviews; // Can be empty
  final List<int?> nullableRatings; // Nullable elements
}

Future<void> nullableCollectionsExample() async {
  print('\n=== Nullable Collections Example ===\n');

  final connection = SqliteConnection.memory();
  await connection.open();

  final repository = ProductSqliteRepository(connection);
  await repository.createTables();

  // Create product with null and empty collections
  final product = Product(
    id: UuidValue.generate(),
    name: 'New Product',
    optionalTags: null, // Null collection
    reviews: [], // Empty collection
    nullableRatings: [5, null, 4, null, 3], // Nullable elements
  );

  print('Saving product with null/empty collections...');
  await repository.save(product);

  print('Loading product...');
  final loaded = await repository.getById(product.id);

  print('Name: ${loaded.name}');
  print('Optional tags: ${loaded.optionalTags}'); // Returns empty set
  print('Reviews: ${loaded.reviews}'); // Returns empty list
  print('Nullable ratings: ${loaded.nullableRatings}');

  // Update with actual values
  print('\nUpdating with actual values...');
  final updated = Product(
    id: loaded.id,
    name: loaded.name,
    optionalTags: {'electronics', 'gadgets'},
    reviews: ['Great product!', 'Highly recommended'],
    nullableRatings: [5, 4, 4, 5, 3],
  );

  await repository.save(updated);
  final reloaded = await repository.getById(product.id);
  print('Updated tags: ${reloaded.optionalTags}');
  print('Updated reviews: ${reloaded.reviews}');
  print('Updated ratings: ${reloaded.nullableRatings}');

  await connection.close();
  print('\n✓ Nullable collections example completed');
}

// ============================================================================
// Example 5: Cascade Delete
// ============================================================================

Future<void> cascadeDeleteExample() async {
  print('\n=== Cascade Delete Example ===\n');

  final connection = SqliteConnection.memory();
  await connection.open();

  final repository = ShoppingCartSqliteRepository(connection);
  await repository.createTables();

  // Create cart with collections
  final cart = ShoppingCart(
    id: UuidValue.generate(),
    userId: UuidValue.generate(),
    items: [
      CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Item 1',
        quantity: 1,
        price: Money(amount: 10.0, currency: 'USD'),
      ),
      CartItem(
        id: UuidValue.generate(),
        productId: UuidValue.generate(),
        productName: 'Item 2',
        quantity: 2,
        price: Money(amount: 20.0, currency: 'USD'),
      ),
    ],
    appliedDiscounts: {
      Discount(
        id: UuidValue.generate(),
        code: 'TEST',
        percentage: 10.0,
        description: 'Test discount',
      ),
    },
    savedItems: {},
  );

  print('Saving cart with ${cart.items.length} items...');
  await repository.save(cart);

  // Verify items exist
  final itemsResult = await connection.query(
    'SELECT COUNT(*) as count FROM cart_items WHERE shopping_cart_id = ?',
    [connection.dialect.encodeUuid(cart.id)],
  );
  print('Items in database: ${itemsResult.first['count']}');

  final discountsResult = await connection.query(
    'SELECT COUNT(*) as count FROM discounts WHERE shopping_cart_id = ?',
    [connection.dialect.encodeUuid(cart.id)],
  );
  print('Discounts in database: ${discountsResult.first['count']}');

  // Delete cart
  print('\nDeleting cart...');
  await repository.deleteById(cart.id);

  // Verify cascade delete
  final itemsAfter = await connection.query(
    'SELECT COUNT(*) as count FROM cart_items WHERE shopping_cart_id = ?',
    [connection.dialect.encodeUuid(cart.id)],
  );
  print('Items after delete: ${itemsAfter.first['count']}');

  final discountsAfter = await connection.query(
    'SELECT COUNT(*) as count FROM discounts WHERE shopping_cart_id = ?',
    [connection.dialect.encodeUuid(cart.id)],
  );
  print('Discounts after delete: ${discountsAfter.first['count']}');

  await connection.close();
  print('\n✓ Cascade delete example completed');
}

// ============================================================================
// Main
// ============================================================================

void main() async {
  print('DDDart SQLite Collection Examples');
  print('==================================');

  await primitiveCollectionsExample();
  await valueObjectCollectionsExample();
  await entityCollectionsExample();
  await nullableCollectionsExample();
  await cascadeDeleteExample();

  print('\n✓ All examples completed successfully!');
}
