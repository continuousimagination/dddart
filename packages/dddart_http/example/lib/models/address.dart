import 'package:dddart/dddart.dart';

/// Value object representing a physical address
/// 
/// VALUE OBJECT PATTERN:
/// A value object is an immutable object that is defined by its attributes
/// rather than a unique identity. Two value objects with the same attributes
/// are considered equal and interchangeable.
/// 
/// Characteristics of this Address value object:
/// 
/// 1. IMMUTABILITY:
///    - All fields are final
///    - Constructor is const, ensuring compile-time immutability
///    - No setter methods or mutable operations
///    - To "change" an address, you create a new Address instance
/// 
/// 2. EQUALITY BY VALUE:
///    - Extends Value from dddart, which provides value-based equality
///    - Two addresses with same street, city, state, zipCode, country are equal
///    - The 'props' getter defines which fields participate in equality
///    - No identity field (no 'id') - identity comes from the values
/// 
/// 3. NO INDEPENDENT LIFECYCLE:
///    - Address cannot exist on its own in the domain
///    - Always part of an aggregate (User in this case)
///    - No createdAt/updatedAt - lifecycle tied to parent entity
///    - Persisted and retrieved as part of the User aggregate
/// 
/// 4. SELF-VALIDATION:
///    - In a production system, the constructor would validate inputs
///    - Example: ensure zipCode matches country format, city is not empty, etc.
///    - Validation ensures Address is always in a valid state
/// 
/// WHEN TO USE VALUE OBJECTS:
/// - When you care about the attributes, not identity
/// - When immutability is desired
/// - When you want value-based equality
/// - Examples: Money, DateRange, EmailAddress, PhoneNumber, Coordinates
class Address extends Value {
  /// Creates an Address with the specified properties
  /// 
  /// In a production system, this constructor would validate:
  /// - street is not empty
  /// - city is not empty
  /// - state matches valid state codes
  /// - zipCode matches the country's postal code format
  /// - country is a valid country code or name
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  /// Street address (e.g., "123 Main St", "456 Oak Ave Apt 2B")
  final String street;

  /// City name (e.g., "Springfield", "Portland")
  final String city;

  /// State or province code (e.g., "IL", "OR", "ON")
  final String state;

  /// Postal/ZIP code (e.g., "62701", "97201", "M5H 2N2")
  final String zipCode;

  /// Country name or code (e.g., "USA", "Canada", "United Kingdom")
  final String country;

  /// Defines which properties participate in equality comparison
  /// 
  /// Two Address instances are equal if all these properties are equal.
  /// This is used by the Value base class to implement == and hashCode.
  @override
  List<Object?> get props => [street, city, state, zipCode, country];
}
