# DDDart JSON Serialization Example

This example demonstrates the complete DDDart JSON serialization system with a realistic e-commerce domain model.

## Domain Model

The example includes:
- **Order** (AggregateRoot) - The main aggregate containing order information
- **OrderItem** (Value) - Individual items within an order
- **Customer** (AggregateRoot) - Customer information
- **Address** (Value) - Shipping and billing addresses
- **Money** (Value) - Price and total amounts
- **ProductInfo** (Value) - Product details

## Features Demonstrated

- ✅ AggregateRoot serialization with nested entities
- ✅ Value object serialization
- ✅ Collections of entities and values
- ✅ Complex nested object graphs
- ✅ Field naming strategies (camelCase, snake_case, kebab-case)
- ✅ Constructor configuration with method overrides
- ✅ Error handling and validation
- ✅ Round-trip serialization integrity

## Running the Example

1. **Install dependencies**:
```bash
dart pub get
```

2. **Generate serialization code**:
```bash
dart run build_runner build
```

3. **Run the example**:
```bash
dart run example/serialization_example.dart
```

## Code Structure

```
example/
├── lib/
│   ├── domain/
│   │   ├── order.dart          # Order aggregate root
│   │   ├── customer.dart       # Customer aggregate root
│   │   ├── order_item.dart     # OrderItem value object
│   │   ├── address.dart        # Address value object
│   │   ├── money.dart          # Money value object
│   │   └── product_info.dart   # ProductInfo value object
│   └── example.dart            # Main example code
├── serialization_example.dart  # Entry point
├── pubspec.yaml
├── build.yaml
└── README.md
```

## Key Concepts

### 1. Domain Model Design

The example follows proper DDD patterns:
- Aggregates maintain consistency boundaries
- Values are immutable and safely shareable
- Business logic is encapsulated in domain objects

### 2. Serialization Configuration

Different serialization strategies for different contexts:
```dart
// API uses snake_case
final apiSerializer = OrderJsonSerializer(
  SerializationConfig(fieldRename: FieldRename.snake)
);

// Database uses camelCase
final dbSerializer = OrderJsonSerializer(
  SerializationConfig(fieldRename: FieldRename.none)
);

// Cache uses kebab-case
final cacheConfig = SerializationConfig(fieldRename: FieldRename.kebab);
final cacheJson = apiSerializer.toJson(order, cacheConfig);
```

### 3. Error Handling

Comprehensive error handling with descriptive messages:
```dart
try {
  final order = serializer.fromJson(invalidJson);
} on DeserializationException catch (e) {
  print('Deserialization failed: ${e.message}');
  print('Expected type: ${e.expectedType}');
  print('Field: ${e.field}');
}
```

### 4. Performance Considerations

- Code generation eliminates runtime reflection
- Type-safe operations with compile-time checking
- Efficient JSON handling with direct Map operations
- Optimized for tree shaking in production builds

## Sample Output

The example generates JSON like:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2024-01-01T12:00:00.000Z",
  "updated_at": "2024-01-01T12:00:00.000Z",
  "customer_id": "550e8400-e29b-41d4-a716-446655440001",
  "items": [
    {
      "product": {
        "name": "Laptop",
        "sku": "LAP-001",
        "category": "Electronics"
      },
      "quantity": 1,
      "unit_price": {
        "amount": 999.99,
        "currency": "USD"
      }
    }
  ],
  "shipping_address": {
    "street": "123 Main St",
    "city": "Anytown",
    "state": "CA",
    "zip_code": "12345",
    "country": "USA"
  },
  "status": "pending"
}
```

## Best Practices

1. **Keep aggregates focused** - Each aggregate should have a single responsibility
2. **Use values for shared concepts** - Address, Money, etc. can be reused across aggregates
3. **Configure serializers at construction** - Set up different serializers for different contexts
4. **Handle errors gracefully** - Always catch DeserializationException for external data
5. **Test round-trip integrity** - Ensure serialize/deserialize maintains object equality
6. **Use static methods for convenience** - `OrderJsonSerializer.encode()` for simple cases

## Integration Examples

The example shows integration with:
- REST APIs (different field naming conventions)
- Database storage (optimized for queries)
- Caching systems (compact representations)
- Message queues (reliable serialization)

This demonstrates how DDDart serialization adapts to different infrastructure requirements while maintaining domain model integrity.
