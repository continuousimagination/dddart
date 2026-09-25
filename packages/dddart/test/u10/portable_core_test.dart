/// Public core primitives must compile and behave identically on VM and web.
library;

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

class _Item extends AggregateRoot {
  _Item();
}

void main() {
  test('identity and repository round-trip through the public barrel',
      () async {
    final item = _Item();
    final Repository<_Item> repo = InMemoryRepository<_Item>();
    await repo.save(item);
    expect((await repo.getById(item.id)).id, item.id);
  });
  test('UUID validation remains available on web', () {
    expect(() => UuidValue.fromString('not-a-uuid'), throwsArgumentError);
  });
  test('typed missing repository outcome remains portable', () async {
    await expectLater(
      InMemoryRepository<_Item>().getById(UuidValue.generate()),
      throwsA(isA<RepositoryException>()),
    );
  });
}
