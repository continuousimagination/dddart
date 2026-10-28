import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Encodes an exact MongoDB binary primary key from a registered identity.
///
/// Binary keys preserve equality even when a collection uses language collation.
/// The original structural JSON identity remains in the document's id field.
/// Keys must be lossless UTF-8 and smaller than MongoDB's BSON document limit;
/// the server still enforces the complete document size and other constraints.
BsonBinary encodeMongoIdentityKey<I extends Identity>(
  IdentityCodecRegistry codecs,
  I identity,
) {
  final key = codecs.toKey<I>(identity);
  final bytes = utf8.encode(key);
  if (utf8.decode(bytes) != key || bytes.length >= 16 * 1024 * 1024) {
    throw const RepositoryException(
      'MongoDB identity key must be lossless UTF-8 and fit in a BSON document',
      type: RepositoryExceptionType.constraint,
    );
  }
  return BsonBinary.from(bytes);
}
