import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Base class for immutable value objects in Domain-Driven Design.
///
/// Value objects are immutable objects that are defined by their attributes
/// rather than their identity. Two value objects are considered equal if all
/// their attributes are equal.
///
/// This implementation eliminates boilerplate equality, hashCode, and toString
/// logic while requiring only a single line to specify which properties define
/// the value object's identity.
///
/// ## Usage
///
/// Subclasses should:
/// - Be immutable (all fields should be final)
/// - Use const constructors when possible
/// - Override [props] to return all property values that define equality
///
/// ## Example
///
/// ```dart
/// class Money extends Value {
///   const Money(this.amount, this.currency);
///
///   final double amount;
///   final String currency;
///
///   @override
///   List<Object?> get props => [amount, currency];
/// }
/// ```
///
/// ## Benefits
///
/// - **Eliminates boilerplate**: No need to implement `operator ==`, `hashCode`, or `toString`
/// - **Consistent behavior**: All value objects get the same reliable equality semantics
/// - **Explicit control**: Clear documentation of which properties define identity
/// - **Const support**: Works with const constructors for compile-time constants
/// - **No reflection or code generation**: Equality works with ordinary Dart values
///
/// ## For True Value Objects
///
/// In most cases, all properties should be included in [props] since value objects
/// are defined by their complete state. Only exclude properties in rare cases where
/// certain fields don't contribute to the object's logical identity.
@immutable
abstract class Value {
  /// Creates a const Value.
  ///
  /// This constructor enables subclasses to be const constructible,
  /// which is important for value object immutability.
  const Value();

  static const _collectionEquality = DeepCollectionEquality();

  /// Properties that define this value object's identity.
  ///
  /// Subclasses must override this method to return all properties that
  /// should be considered for equality comparison. For true value objects,
  /// this should typically include all properties.
  ///
  /// The order of properties in this list matters for equality comparison.
  /// Nested lists and other iterables compare in order; sets and maps compare
  /// without regard to insertion order. Keep nested collections immutable:
  /// changing one after using a Value as a map key or set member can change
  /// its hash code. Cyclic collections are not supported.
  List<Object?> get props;

  /// Determines whether two value objects are equal.
  ///
  /// Two value objects are equal if they are of the same type and
  /// all their properties (as defined by [props]) are equal.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! Value) return false;

    return _collectionEquality.equals(props, other.props);
  }

  /// Returns a hash code for this value object.
  ///
  /// The hash code is calculated based on all properties defined by [props].
  @override
  int get hashCode {
    final properties = props;
    // Preserve the existing scalar-only hash behavior. Collections need the
    // same structural treatment as equality, including nested set/map order.
    if (properties
        .every((property) => property is! Iterable && property is! Map)) {
      return Object.hashAll(properties);
    }
    return _collectionEquality.hash(properties);
  }

  /// Returns a string representation of this value object.
  ///
  /// The string includes the class name and all properties defined by [props].
  @override
  String toString() {
    final className = runtimeType.toString();
    final propsString = props.join(', ');
    return '$className($propsString)';
  }
}
