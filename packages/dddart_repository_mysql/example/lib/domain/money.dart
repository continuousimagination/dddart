import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

part 'money.g.dart';

/// Value object representing a monetary amount with currency.
@Serializable()
class Money extends Value {
  /// Creates a new Money value object.
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
