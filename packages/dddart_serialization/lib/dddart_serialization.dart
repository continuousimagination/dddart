/// Serialization framework for DDDart.
///
/// This package provides the base framework for implementing serialization
/// in DDDart applications. It includes the @Serializable annotation,
/// common utilities, configuration classes, and base classes for building
/// format-specific serializers.
///
/// For JSON serialization, use the `dddart_json` package.
library dddart_serialization;

export 'src/serializable_annotation.dart';
export 'src/serialization_config.dart';
export 'src/serialization_contracts.dart';
export 'src/serialization_utils.dart';
