import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  test('Mongo keys preserve exact case, Unicode and scope', () {
    final codecs = identityCodecs();
    final upper =
        encodeMongoIdentityKey<NativeId>(codecs, const NativeId('IssueA'));
    final lower =
        encodeMongoIdentityKey<NativeId>(codecs, const NativeId('issuea'));
    expect(upper.byteList, isNot(lower.byteList));
    final first = encodeMongoIdentityKey<ScopedId>(
      codecs,
      const ScopedId('org/%, café', 12),
    );
    final second =
        encodeMongoIdentityKey<ScopedId>(codecs, const ScopedId('other', 12));
    expect(first.byteList, isNot(second.byteList));
  });

  test('malformed Unicode is rejected before opening a Mongo connection',
      () async {
    final repo = NativeIssueMongoRepository(
      Db('mongodb://127.0.0.1:1/not_open'),
      identityCodecs: identityCodecs(),
    );
    final id = NativeId(String.fromCharCode(0xd800));
    final constraint = throwsA(
      isA<RepositoryException>()
          .having((e) => e.type, 'type', RepositoryExceptionType.constraint),
    );
    await expectLater(repo.save(NativeIssue(id: id, label: 'bad')), constraint);
    await expectLater(repo.getById(id), constraint);
    await expectLater(repo.deleteById(id), constraint);
  });
}
