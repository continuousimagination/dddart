import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'address.g.dart';

/// Value object representing a physical address.
@Serializable()
class Address extends Value {
  /// Creates a new Address value object.
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  /// Street address.
  final String street;

  /// City name.
  final String city;

  /// State or province.
  final String state;

  /// Postal or ZIP code.
  final String postalCode;

  /// Country name.
  final String country;

  @override
  List<Object?> get props => [street, city, state, postalCode, country];
}
