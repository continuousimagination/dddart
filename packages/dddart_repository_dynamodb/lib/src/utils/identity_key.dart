import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

/// Encodes a DynamoDB string partition key using the registered identity codec.
///
/// DynamoDB requires 1–2048 UTF-8 bytes for this key. Reject malformed Unicode
/// instead of allowing UTF-8 replacement to collapse distinct identities.
String encodeDynamoIdentityKey<I extends Identity>(
  IdentityCodecRegistry codecs,
  I identity,
) {
  final key = codecs.toKey<I>(identity);
  final bytes = utf8.encode(key);
  if (bytes.isEmpty || bytes.length > 2048 || utf8.decode(bytes) != key) {
    throw const RepositoryException(
      'DynamoDB identity key must contain 1–2048 lossless UTF-8 bytes',
      type: RepositoryExceptionType.constraint,
    );
  }
  return key;
}
