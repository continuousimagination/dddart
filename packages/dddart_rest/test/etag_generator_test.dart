import 'package:dddart_rest/dddart_rest.dart';
import 'package:test/test.dart';

void main() {
  test('strong validators encode opaque revisions losslessly and canonically',
      () {
    for (final revision in [
      'token',
      'a/b?c="d"',
      'café',
      List.filled(1024, 'x').join(),
    ]) {
      final tag = RevisionETag.encode(revision);
      expect(tag, startsWith('"r1.'));
      expect(tag, endsWith('"'));
      expect(tag.codeUnits.every((c) => c < 128), isTrue);
      expect(RevisionETag.tryDecode(tag), revision);
      expect(RevisionETag.tryDecode('W/$tag'), isNull);
    }
  });
  test(
      'unknown and noncanonical validators do not decode to accepted revisions',
      () {
    for (final tag in [
      '"unknown"',
      'r1.dG9rZW4',
      '"r1.dG9rZW4="',
      '"r1."',
      '"r1.%%%"',
    ]) {
      expect(RevisionETag.tryDecode(tag), isNull);
    }
    expect(() => RevisionETag.encode(''), throwsArgumentError);
  });
  test('quoted commas are tag content; weak and unknown tags cannot match', () {
    final tag = RevisionETag.encode('actual');
    final condition =
        WritePrecondition.parse({'if-match': '"one,two", W/"three", $tag'});
    expect(condition!.revisions, ['actual']);
  });
}
