import 'package:dddart/dddart.dart';

/// Strict grammar for the fixed canonical JSON conditional representation.
///
/// These validators are meaningful only within a stable representation/API
/// namespace. Changing serialized bytes requires a new representation namespace.
abstract final class ConditionalHeaders {
  /// Encodes a positive persisted revision as one strong validator.
  static String etag(Revision revision) {
    if (revision.value == 0) {
      throw ArgumentError('A positive revision is required.');
    }
    return '"r${revision.value}"';
  }

  /// Parses one exact canonical strong validator without whitespace or lists.
  static Revision parseEtag(String? value) {
    if (value == null) {
      throw const FormatException('Invalid revision validator.');
    }
    final match = RegExp('"r([1-9][0-9]*)"').matchAsPrefix(value);
    if (match == null || match.end != value.length) {
      throw const FormatException('Invalid revision validator.');
    }
    final number = int.tryParse(match.group(1)!);
    if (number == null || number > Revision.maxValue) {
      throw const FormatException('Invalid revision validator.');
    }
    return Revision(number);
  }

  /// Returns the only mutation header authorized by an explicit expectation.
  static Map<String, String> forWrite(WritePrecondition precondition) =>
      switch (precondition) {
        AbsentWritePrecondition() => {'If-None-Match': '*'},
        RevisionWritePrecondition(:final revision) => {
          'If-Match': etag(revision),
        },
      };

  /// Parses a mutation expectation, rejecting duplicates and unsupported
  /// conditional/range fields. Authentication and body agreement are separate.
  static WritePrecondition parseWrite(
    Map<String, String> headers, {
    bool allowCreate = true,
  }) {
    final conditions = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.toLowerCase();
      if (name.startsWith('if-') || name == 'range') {
        if (!const {'if-match', 'if-none-match'}.contains(name) ||
            conditions.containsKey(name)) {
          throw const FormatException('Invalid write precondition.');
        }
        conditions[name] = entry.value;
      }
    }
    if (conditions.isEmpty) throw const PreconditionRequiredException();
    if (conditions.length != 1) {
      throw const FormatException('Invalid write precondition.');
    }
    if (conditions.containsKey('if-match')) {
      return WritePrecondition.atRevision(parseEtag(conditions['if-match']));
    }
    if (!allowCreate || conditions['if-none-match'] != '*') {
      throw const FormatException('Invalid write precondition.');
    }
    return const WritePrecondition.absent();
  }
}
