import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';
import 'address.dart';

part 'customer.g.dart';

/// Aggregate root representing a customer.
@Serializable()
class Customer extends AggregateRoot {
  Customer({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.defaultShippingAddress,
    this.defaultBillingAddress,
    super.id,
    super.createdAt,
    super.updatedAt,
  });

  final String firstName;
  final String lastName;
  final String email;
  final Address defaultShippingAddress;
  final Address? defaultBillingAddress;

  /// Get the customer's full name
  String get fullName => '$firstName $lastName';

  /// Get the billing address, falling back to shipping if not set
  Address get billingAddress => defaultBillingAddress ?? defaultShippingAddress;

  /// Check if customer has a separate billing address
  bool get hasSeparateBillingAddress => defaultBillingAddress != null;

  @override
  String toString() => 'Customer($fullName, $email)';

  /// Create a copy with updated shipping address
  Customer withShippingAddress(Address newAddress) {
    return Customer(
      firstName: firstName,
      lastName: lastName,
      email: email,
      defaultShippingAddress: newAddress,
      defaultBillingAddress: defaultBillingAddress,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy with updated billing address
  Customer withBillingAddress(Address? newAddress) {
    return Customer(
      firstName: firstName,
      lastName: lastName,
      email: email,
      defaultShippingAddress: defaultShippingAddress,
      defaultBillingAddress: newAddress,
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Validate customer data
  bool get isValid {
    return firstName.isNotEmpty &&
           lastName.isNotEmpty &&
           email.contains('@') &&
           email.contains('.');
  }
}
