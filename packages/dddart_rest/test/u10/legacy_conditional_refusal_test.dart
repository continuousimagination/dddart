/// Legacy CRUD must not pretend its read/check/save path is atomic.
library;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../crud_resource_test.dart' show TestUser, TestUserSerializer;

class _Repository<T extends AggregateRoot> implements Repository<T> {
  _Repository(this.value);
  final T value;
  final calls = <String>[];
  @override
  Future<T> getById(UuidValue id) async {
    calls.add('read');
    return value;
  }

  @override
  Future<void> save(T value) async {
    calls.add('save');
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    calls.add('delete');
  }
}

class _Codec<T> implements Serializer<T> {
  _Codec(this.value);
  final T value;
  @override
  T deserialize(String data, [dynamic config]) => value;
  @override
  String serialize(T value, [dynamic config]) => '{}';
}

void main() {
  test(
    'every conditional legacy mutation rejects before all repository I/O',
    () async {
      final user = TestUser(name: 'synthetic', email: 'synthetic');
      final codec = TestUserSerializer();
      final repository = _Repository(user);
      final resource = CrudResource<TestUser, void>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': codec},
      );
      for (final method in ['PUT', 'POST', 'DELETE']) {
        for (final name in [
          'if-match',
          'if-none-match',
          'if-unmodified-since',
          'if-range',
        ]) {
          final request = Request(
            method,
            Uri.parse('http://local/users/${user.id}'),
            headers: {name: 'value', 'content-type': 'application/json'},
            body: method == 'DELETE' ? null : codec.serialize(user),
          );
          final response = await switch (method) {
            'PUT' => resource.handleUpdate(request, user.id.uuid),
            'POST' => resource.handleCreate(request),
            _ => resource.handleDelete(request, user.id.uuid),
          };
          expect(response.statusCode, 501, reason: '$method $name');
          expect(repository.calls, isEmpty);
        }
      }
    },
  );
  test(
    'ordinary legacy PUT succeeds without transformed-representation validators',
    () async {
      final user = TestUser(name: 'synthetic', email: 'synthetic');
      final codec = TestUserSerializer();
      final repository = _Repository(user);
      final resource = CrudResource<TestUser, void>(
        path: '/users',
        repository: repository,
        serializers: {'application/json': codec},
      );
      final response = await resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/users/${user.id}'),
          headers: {'content-type': 'application/json'},
          body: codec.serialize(user),
        ),
        user.id.uuid,
      );
      expect(response.statusCode, 200);
      expect(response.headers['etag'], isNull);
      expect(response.headers['last-modified'], isNull);
      expect(repository.calls, ['save']);
    },
  );
  test(
    'versioned legacy registration and widened decoded values are rejected',
    () async {
      final value = VersionedRecord(
        text: 'synthetic',
        tags: [],
        id: UuidValue.generate(),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(
        () => CrudResource<VersionedRecord, void>(
          path: '/records',
          repository: _Repository(value),
          serializers: {'application/json': VersionedRecordJsonSerializer()},
        ),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      final repository = _Repository<AggregateRoot>(value);
      final resource = CrudResource<AggregateRoot, void>(
        path: '/records',
        repository: repository,
        serializers: {'application/json': _Codec<AggregateRoot>(value)},
      );
      final response = await resource.handleUpdate(
        Request(
          'PUT',
          Uri.parse('http://local/records/${value.id}'),
          body: '{}',
        ),
        value.id.uuid,
      );
      expect(response.statusCode, 501);
      expect(repository.calls, isEmpty);
    },
  );
  test('conditional exceptions retain their specific HTTP status', () {
    for (final (error, status) in [
      (const PreconditionFailedException(), 412),
      (const PreconditionRequiredException(), 428),
      (const RepositoryCapabilityException(), 501),
      (const RevisionCapacityException(), 413),
    ]) {
      expect(
        ErrorMapper.mapException(error, StackTrace.empty).statusCode,
        status,
      );
    }
  });
}
