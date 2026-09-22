import 'package:dddart/src/conditional_repository_exception.dart';
import 'package:dddart/src/value.dart';

/// Portable optimistic concurrency revision; zero denotes unpersisted state.
final class Revision extends Value {
  /// Validates [value] without relying on assertions.
  factory Revision(int value) {
    if (value < 0 || value > maxValue) {
      throw RangeError.range(value, 0, maxValue, 'value');
    }
    return Revision._(value);
  }

  /// Decodes a finite whole numeric JSON value into a portable integer.
  ///
  /// Validates the decoded numeric value before conversion. Standard JSON
  /// parsing may already have rounded a decimal token; this does not promise
  /// preservation or validation of the original lexical spelling.
  factory Revision.fromJson(Object? value) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > maxValue ||
        value % 1 != 0) {
      throw const FormatException('Invalid revision value');
    }
    return Revision._(value.toInt());
  }

  /// Creates the unpersisted revision.
  const Revision.zero() : value = 0;

  const Revision._(this.value);

  /// Largest exactly representable portable JSON integer.
  static const int maxValue = 9007199254740991;

  /// Numeric wire representation.
  final int value;

  /// Returns the next revision, failing before any storage operation at capacity.
  Revision next() {
    if (value == maxValue) throw const RevisionCapacityException();
    return Revision._(value + 1);
  }

  @override
  List<Object?> get props => [value];
}
