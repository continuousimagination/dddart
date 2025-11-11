import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';

part 'address.g.dart';

/// Value object representing a physical address.
@Serializable()
class Address extends Value {
  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  @override
  List<Object?> get props => [street, city, state, zipCode, country];

  @override
  String toString() => '$street, $city, $state $zipCode, $country';

  /// Create a formatted address string for shipping labels
  String toShippingLabel() {
    return [
      street,
      '$city, $state $zipCode',
      country,
    ].join('\n');
  }

  /// Check if this is a US address
  bool get isUSAddress =>
      country.toUpperCase() == 'USA' || country.toUpperCase() == 'US';

  /// Get the full city/state/zip line
  String get cityStateZip => '$city, $state $zipCode';
}
