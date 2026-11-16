import 'dart:convert';

import 'package:dddart/dddart.dart';

/// Strong HTTP validators for opaque, storage-owned aggregate revisions.
abstract final class RevisionETag {
  /// Encodes a revision as a quoted, ASCII entity tag.
  static String encode(String revision) {
    validateExpectedRevision(ExpectedRevision.match(revision));
    return '"r1.${base64Url.encode(utf8.encode(revision)).replaceAll('=', '')}"';
  }

  /// Decodes canonical validators from this protocol; other tags never match.
  static String? tryDecode(String tag) {
    if (!tag.startsWith('"r1.') || !tag.endsWith('"')) return null;
    try {
      final revision = utf8.decode(
        base64Url.decode(base64Url.normalize(tag.substring(4, tag.length - 1))),
      );
      return encode(revision) == tag ? revision : null;
    } on FormatException {
      return null;
      // Revision validation deliberately reports ArgumentError for invalid tokens.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }
}

/// An HTTP precondition failure that has not performed a mutation.
class PreconditionException implements Exception {
  /// No strong validator in the supplied condition can match.
  const PreconditionException.failed()
      : status = 412,
        title = 'Precondition Failed',
        detail =
            'The resource no longer matches the supplied condition. Fetch it before choosing a new write.';

  /// The resource requires an explicit condition for PUT and DELETE.
  const PreconditionException.required()
      : status = 428,
        title = 'Precondition Required',
        detail = 'Supply If-Match or If-None-Match: * for this mutation.';

  /// This valid header shape cannot be expressed by the supported capability.
  const PreconditionException.unsupported(this.detail)
      : status = 501,
        title = 'Not Implemented';

  /// HTTP status.
  final int status;

  /// Problem title.
  final String title;

  /// Public explanation, without current resource content or revision.
  final String detail;
}

/// Parsed write conditions, resolved into one atomic repository condition.
///
/// Strong tag lists select a matching stored revision, which is still checked
/// atomically at mutation time. Weak tags cannot match. `If-Match: *` is rejected
/// explicitly: an existence-only mutation is not part of the shared capability.
/// `If-None-Match: *` maps to create/assert-absence; other shapes are unsupported.
final class WritePrecondition {
  const WritePrecondition._(this.revisions, {this.absent = false});

  /// Candidate storage revisions from strong entity tags.
  final List<String> revisions;

  /// Whether the resource must be absent.
  final bool absent;

  /// Parses headers without silently converting an unsupported condition to CRUD.
  static WritePrecondition? parse(
    Map<String, String> headers, {
    bool required = false,
  }) {
    final match = headers['if-match'];
    final none = headers['if-none-match'];
    if (match != null && none != null) {
      throw const FormatException(
        'Supply either If-Match or If-None-Match, not both.',
      );
    }
    if (none != null) {
      if (none.trim() == '*') {
        return const WritePrecondition._([], absent: true);
      }
      _tags(none);
      throw const PreconditionException.unsupported(
        'Only If-None-Match: * is supported for mutations.',
      );
    }
    if (match == null) {
      if (required) throw const PreconditionException.required();
      return null;
    }
    if (match.trim() == '*') {
      throw const PreconditionException.unsupported(
        'If-Match: * is not supported. GET a revision and send its strong ETag.',
      );
    }
    final revisions = <String>[];
    for (final tag in _tags(match)) {
      if (tag.weak) continue;
      final revision = RevisionETag.tryDecode(tag.value);
      if (revision != null) revisions.add(revision);
    }
    if (revisions.isEmpty) throw const PreconditionException.failed();
    return WritePrecondition._(List.unmodifiable(revisions.toSet()));
  }

  /// Resolves a list, retaining a storage condition even after a matching read.
  Future<ExpectedRevision>
      resolve<T extends AggregateRoot<I>, I extends Identity>(
    ConditionalAggregateRepository<T, I> repository,
    I id,
  ) async {
    if (absent) return const ExpectedRevision.absent();
    if (revisions.length == 1) return ExpectedRevision.match(revisions.single);
    try {
      final current = await repository.getVersioned(id);
      if (revisions.contains(current.revision)) {
        return ExpectedRevision.match(current.revision);
      }
    } on RepositoryException catch (error) {
      if (error.type != RepositoryExceptionType.notFound) rethrow;
    }
    throw const PreconditionException.failed();
  }

  static List<({String value, bool weak})> _tags(String header) {
    var offset = 0;
    final tags = <({String value, bool weak})>[];
    void whitespace() {
      while (offset < header.length &&
          (header[offset] == ' ' || header[offset] == '\t')) {
        offset++;
      }
    }

    while (true) {
      whitespace();
      // HTTP list parsing tolerates empty list members.
      while (offset < header.length && header[offset] == ',') {
        offset++;
        whitespace();
      }
      if (offset == header.length) break;
      var weak = false;
      if (header.startsWith('W/', offset)) {
        weak = true;
        offset += 2;
      }
      final start = offset;
      if (offset >= header.length || header[offset++] != '"') {
        throw const FormatException('Expected a quoted entity tag.');
      }
      while (offset < header.length && header[offset] != '"') {
        final code = header.codeUnitAt(offset++);
        if (code < 0x21 || code == 0x7f || code > 0xff) {
          throw const FormatException('Invalid entity-tag character.');
        }
      }
      if (offset == header.length) {
        throw const FormatException('Unterminated entity tag.');
      }
      offset++;
      tags.add((value: header.substring(start, offset), weak: weak));
      whitespace();
      if (offset == header.length) break;
      if (header[offset] != ',') {
        throw const FormatException('Expected a comma between entity tags.');
      }
    }
    if (tags.isEmpty) {
      throw const FormatException('An entity-tag list cannot be empty.');
    }
    return tags;
  }
}
