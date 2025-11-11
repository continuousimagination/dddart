import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_json/dddart_json.dart';

part 'money.g.dart';

/// Value object representing a monetary amount with currency.
@Serializable()
class Money extends Value {
  const Money({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  List<Object?> get props => [amount, currency];

  @override
  String toString() => '$amount $currency';

  /// Create zero amount in the given currency
  Money.zero(String currency) : this(amount: 0.0, currency: currency);

  /// Add two money amounts (must be same currency)
  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
          'Cannot add different currencies: $currency + ${other.currency}');
    }
    return Money(amount: amount + other.amount, currency: currency);
  }

  /// Multiply money by a factor
  Money operator *(double factor) {
    return Money(amount: amount * factor, currency: currency);
  }

  /// Check if this amount is greater than another
  bool operator >(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
          'Cannot compare different currencies: $currency > ${other.currency}');
    }
    return amount > other.amount;
  }

  /// Check if this is a positive amount
  bool get isPositive => amount > 0;

  /// Check if this is zero
  bool get isZero => amount == 0;
}
