import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Strategy for generating ETags from aggregate roots
enum ETagStrategy {
  /// Use the aggregate's updatedAt timestamp (fast, less precise)
  timestamp,

  /// Use SHA-256 hash of serialized content (slower, more precise)
  contentHash,
}

/// Generates ETags for aggregate roots to support optimistic concurrency control
///
/// ETags are used in HTTP conditional requests (If-Match header) to prevent
/// lost updates when multiple clients modify the same resource concurrently.
///
/// Two strategies are supported:
/// - [ETagStrategy.timestamp]: Uses the aggregate's updatedAt timestamp
/// - [ETagStrategy.contentHash]: Uses SHA-256 hash of serialized content
///
/// Example:
/// ```dart
/// final generator = ETagGenerator<User>(
///   strategy: ETagStrategy.timestamp,
/// );
/// final etag = generator.generate(user);
/// // Returns: "2024-01-15T10:30:00.000Z"
/// ```
class ETagGenerator<T extends AggregateRoot> {
  /// Creates an ETag generator with the specified strategy
  ///
  /// Parameters:
  /// - [strategy]: The strategy to use for generating ETags (defaults to timestamp)
  /// - [serializer]: Required when using contentHash strategy
  ETagGenerator({
    this.strategy = ETagStrategy.timestamp,
    this.serializer,
  }) {
    if (strategy == ETagStrategy.contentHash && serializer == null) {
      throw ArgumentError(
        'serializer is required when using contentHash strategy',
      );
    }
  }

  /// The strategy to use for generating ETags
  final ETagStrategy strategy;

  /// The serializer to use for contentHash strategy
  final Serializer<T>? serializer;

  /// Generates an ETag for the given aggregate
  ///
  /// The ETag format depends on the strategy:
  /// - timestamp: ISO 8601 timestamp string
  /// - contentHash: SHA-256 hash of serialized content
  ///
  /// ETags are returned as quoted strings per RFC 7232.
  ///
  /// Parameters:
  /// - [aggregate]: The aggregate root to generate an ETag for
  ///
  /// Returns: A quoted ETag string (e.g., "2024-01-15T10:30:00.000Z")
  String generate(T aggregate) {
    return switch (strategy) {
      ETagStrategy.timestamp =>
        '"${aggregate.updatedAt.toUtc().toIso8601String()}"',
      ETagStrategy.contentHash => _generateContentHash(aggregate),
    };
  }

  /// Generates a content hash ETag for the aggregate
  String _generateContentHash(T aggregate) {
    final json = serializer!.serialize(aggregate);
    final hash = sha256.convert(utf8.encode(json));
    return '"$hash"';
  }

  /// Validates that the provided ETag matches the current aggregate state
  ///
  /// Returns true if the ETags match, false otherwise.
  ///
  /// Parameters:
  /// - [providedETag]: The ETag from the If-Match header
  /// - [aggregate]: The current aggregate state
  ///
  /// Returns: true if ETags match, false otherwise
  bool validate(String providedETag, T aggregate) {
    final currentETag = generate(aggregate);
    return providedETag == currentETag;
  }
}
