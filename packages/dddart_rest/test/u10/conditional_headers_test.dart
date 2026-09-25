/// The single portable conditional wire grammar used by client and server.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('positive revisions round trip through strong canonical validators', () {
    for (final n in [1, 42, Revision.maxValue]) {
      expect(
        ConditionalHeaders.parseEtag(ConditionalHeaders.etag(Revision(n))),
        Revision(n),
      );
    }
    expect(
      () => ConditionalHeaders.etag(const Revision.zero()),
      throwsArgumentError,
    );
  });
  test('weak, list, zero, noncanonical and unbounded validators fail', () {
    for (final value in [
      null,
      '',
      '*',
      'W/"r1"',
      '"r1", "r2"',
      '"r0"',
      '"r01"',
      '"r-1"',
      '"r1.0"',
      '"r9007199254740992"',
      ' "r1"',
      '"r1"\n',
    ]) {
      expect(
        () => ConditionalHeaders.parseEtag(value),
        throwsFormatException,
        reason: '$value',
      );
    }
  });
  test('create and update headers preserve the explicit condition', () {
    const create = WritePrecondition.absent();
    final update = WritePrecondition.atRevision(Revision(2));
    expect(
      ConditionalHeaders.parseWrite(ConditionalHeaders.forWrite(create)),
      create,
    );
    expect(
      ConditionalHeaders.parseWrite(ConditionalHeaders.forWrite(update)),
      update,
    );
    expect(ConditionalHeaders.parseWrite({'IF-MATCH': '"r2"'}), update);
  });
  test(
    'missing, conflicting, duplicate and unrelated conditions fail closed',
    () {
      expect(
        () => ConditionalHeaders.parseWrite({}),
        throwsA(isA<PreconditionRequiredException>()),
      );
      for (final headers in [
        {'if-match': '"r1"', 'if-none-match': '*'},
        {'if-match': '"r1"', 'If-Match': '"r1"'},
        {'if-none-match': '"r1"'},
        {'if-none-match': '*, *'},
        {'if-match': '"r1"', 'range': 'bytes=0-1'},
        {'if-match': '"r1"', 'if-unmodified-since': 'today'},
      ]) {
        expect(
          () => ConditionalHeaders.parseWrite(headers),
          throwsFormatException,
        );
      }
      expect(
        () => ConditionalHeaders.parseWrite({
          'if-none-match': '*',
        }, allowCreate: false),
        throwsFormatException,
      );
    },
  );
}
