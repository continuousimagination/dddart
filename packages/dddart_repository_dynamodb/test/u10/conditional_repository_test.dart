/// Actual SDK requests and accepted-copy invariants for conditional persistence.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_dynamodb/dddart_repository_dynamodb.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../test_models.dart' as legacy;
import 'conditional_binding.dart';

class _Transport extends http.BaseClient {
  _Transport(this.reply);
  final Future<http.StreamedResponse> Function(Map<String, dynamic>, String)
  reply;
  final List<Map<String, dynamic>> requests = [];
  final List<String> actions = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    final action =
        request.headers['x-amz-target'] ?? request.headers['X-Amz-Target']!;
    requests.add(body);
    actions.add(action);
    return reply(body, action);
  }
}

http.StreamedResponse _reply(Map<String, dynamic> body, [int status = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/x-amz-json-1.0'},
    );
VersionedRecord _record({
  int revision = 0,
  String text = 'initial',
  UuidValue? id,
}) => VersionedRecord(
  text: text,
  tags: ['one'],
  id: id ?? UuidValue.generate(),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  revision: Revision(revision),
);
DynamoConnection _connect(_Transport transport) => DynamoConnection(
  region: 'us-east-1',
  endpoint: 'https://example.invalid',
  credentials: AwsClientCredentials(
    accessKey: 'synthetic',
    secretKey: 'synthetic',
    sessionToken: 'synthetic',
  ),
  httpClient: transport,
);

void main() {
  test(
    'strong reads normalize equivalent whole Dynamo numeric revisions',
    () async {
      final value = _record(revision: 1);
      final wire = VersionedRecordJsonSerializer().toJson(value);
      for (final token in ['1.0', '1e0', '9007199254740991.0']) {
        final item = AttributeValueConverter.jsonMapToAttributeMap(
          wire,
        ).map((k, v) => MapEntry(k, v.toJson()));
        item['revision'] = {'N': token};
        final transport = _Transport((_, __) async => _reply({'Item': item}));
        final repository = ConditionalProbeDynamoRepository(
          _connect(transport),
          tableName: 'records',
        );
        final observed = await repository.getById(value.id);
        expect(
          observed.revision.value,
          token.startsWith('9007') ? Revision.maxValue : 1,
        );
        expect(transport.requests, hasLength(1));
      }
    },
  );
  test('missing item remains a typed one-read notFound', () async {
    final transport = _Transport((_, __) async => _reply({}));
    final repo = ConditionalProbeDynamoRepository(
      _connect(transport),
      tableName: 'records',
    );
    await expectLater(
      repo.getById(UuidValue.generate()),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.type,
          'type',
          RepositoryExceptionType.notFound,
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test(
    'actual legacy generated adapter rejects a widened versioned subtype before I/O',
    () async {
      final transport = _Transport((_, __) async => _reply({}));
      final repo = legacy.TestUserDynamoRepository(_connect(transport));
      await expectLater(
        repo.save(_WidenedVersioned()),
        throwsA(isA<RepositoryCapabilityException>()),
      );
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'create sends one atomic PutItem and returns independent accepted state',
    () async {
      final transport = _Transport((_, __) async => _reply({}));
      final repo = ConditionalProbeDynamoRepository(
        _connect(transport),
        tableName: 'records',
      );
      final proposed = _record();
      final accepted = await repo.save(
        proposed,
        precondition: const WritePrecondition.absent(),
      );
      expect(transport.requests, hasLength(1));
      expect(transport.actions.single, endsWith('.PutItem'));
      final request = transport.requests.single;
      expect(request['ConditionExpression'], 'attribute_not_exists(#id)');
      expect(request['ExpressionAttributeNames'], {'#id': 'id'});
      expect((request['Item'] as Map)['revision'], {'N': '1'});
      expect(accepted.revision, Revision(1));
      expect(proposed.revision, Revision(0));
      expect(accepted.id, proposed.id);
      expect(accepted.updatedAt, proposed.updatedAt);
      proposed.tags.add('caller');
      expect(accepted.tags, ['one']);
      accepted.tags.add('result');
      expect(((request['Item'] as Map)['tags'] as Map)['L'], [
        {'S': 'one'},
      ]);
    },
  );
  test(
    'same-content update is one condition and advances without reread',
    () async {
      final transport = _Transport((_, __) async => _reply({}));
      final repo = ConditionalProbeDynamoRepository(
        _connect(transport),
        tableName: 'records',
      );
      final value = _record(revision: 7);
      final accepted = await repo.save(
        value,
        precondition: WritePrecondition.atRevision(Revision(7)),
      );
      expect(accepted.revision, Revision(8));
      expect(value.revision, Revision(7));
      expect(transport.requests, hasLength(1));
      expect(
        transport.requests.single['ConditionExpression'],
        'attribute_exists(#id) AND #revision = :expected AND attribute_not_exists(#retired)',
      );
      expect(transport.requests.single['ExpressionAttributeValues'], {
        ':expected': {'N': '7'},
      });
    },
  );
  test('condition failure is typed, safe and never retried', () async {
    final transport = _Transport(
      (_, __) async => _reply({
        '__type':
            'com.amazonaws.dynamodb.v20120810#ConditionalCheckFailedException',
        'message': 'restricted-marker',
      }, 400),
    );
    final repo = ConditionalProbeDynamoRepository(
      _connect(transport),
      tableName: 'records',
    );
    await expectLater(
      repo.save(_record(), precondition: const WritePrecondition.absent()),
      throwsA(
        isA<PreconditionFailedException>().having(
          (e) => e.toString(),
          'safe',
          isNot(contains('restricted-marker')),
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });
  test('read is strong and verifies metadata and decoded identity', () async {
    final value = _record(revision: 2);
    final wire = VersionedRecordJsonSerializer().toJson(value);
    final transport = _Transport(
      (_, __) async => _reply({
        'Item': AttributeValueConverter.jsonMapToAttributeMap(
          wire,
        ).map((k, v) => MapEntry(k, v.toJson())),
      }),
    );
    final repo = ConditionalProbeDynamoRepository(
      _connect(transport),
      tableName: 'records',
    );
    final read = await repo.getById(value.id);
    expect(read.revision, Revision(2));
    expect(read.text, value.text);
    expect(transport.requests.single['ConsistentRead'], isTrue);
    expect(transport.requests.single['Key'], {
      'id': {'S': value.id.uuid},
    });
  });
  test(
    'retirement replaces payload with only minimal fencing metadata',
    () async {
      final transport = _Transport((_, __) async => _reply({}));
      final repo = ConditionalProbeDynamoRepository(
        _connect(transport),
        tableName: 'records',
      );
      final id = UuidValue.generate();
      await repo.deleteById(
        id,
        precondition: WritePrecondition.atRevision(Revision(3)),
      );
      expect(transport.actions.single, endsWith('.PutItem'));
      expect(transport.requests.single['Item'], {
        'id': {'S': id.uuid},
        'revision': {'N': '4'},
        '__dddart_retired': {'BOOL': true},
      });
      expect(transport.requests.single['ExpressionAttributeValues'], {
        ':expected': {'N': '3'},
      });
    },
  );
  test('capacity and mismatch reject before provider dispatch', () async {
    final transport = _Transport((_, __) async => _reply({}));
    final repo = ConditionalProbeDynamoRepository(
      _connect(transport),
      tableName: 'records',
    );
    await expectLater(
      repo.save(
        _record(revision: 1),
        precondition: const WritePrecondition.absent(),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.save(
        _record(revision: Revision.maxValue),
        precondition: WritePrecondition.atRevision(Revision(Revision.maxValue)),
      ),
      throwsA(isA<RevisionCapacityException>()),
    );
    await expectLater(
      repo.deleteById(
        UuidValue.generate(),
        precondition: const WritePrecondition.absent(),
      ),
      throwsArgumentError,
    );
    expect(transport.requests, isEmpty);
  });
  test(
    'read rejects foreign identities, invalid revisions and malformed retirement state',
    () async {
      final value = _record(revision: 1);
      final original = VersionedRecordJsonSerializer().toJson(value);
      final invalid = <Map<String, dynamic>>[
        {...original, 'id': UuidValue.generate().uuid},
        {...original}..remove('revision'),
        for (final revision in [0, -1, 1.5, '1', null, 9007199254740992])
          {...original, 'revision': revision},
        {...original, '__dddart_retired': true},
        {'id': value.id.uuid, 'revision': 2, '__dddart_retired': false},
      ];
      for (final wire in invalid) {
        final transport = _Transport(
          (_, __) async => _reply({
            'Item': AttributeValueConverter.jsonMapToAttributeMap(
              wire,
            ).map((k, v) => MapEntry(k, v.toJson())),
          }),
        );
        final repo = ConditionalProbeDynamoRepository(
          _connect(transport),
          tableName: 'records',
        );
        await expectLater(
          repo.getById(value.id),
          throwsA(
            isA<RepositoryException>().having(
              (e) => e.type,
              'type',
              isNot(RepositoryExceptionType.notFound),
            ),
          ),
        );
        expect(transport.requests, hasLength(1));
      }
      final transport = _Transport(
        (_, __) async => _reply({
          'Item': {
            'id': {'S': value.id.uuid},
            'revision': {'N': '2'},
            '__dddart_retired': {'BOOL': true},
          },
        }),
      );
      final repo = ConditionalProbeDynamoRepository(
        _connect(transport),
        tableName: 'records',
      );
      await expectLater(
        repo.getById(value.id),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.notFound,
          ),
        ),
      );
    },
  );

  test(
    'codec failures, normalized copies and reserved metadata fail before dispatch',
    () async {
      final proposed = _record();
      for (final codec in <VersionedRecordJsonSerializer>[
        _Codec(encode: (wire) => {...wire, '__dddart_retired': false}),
        _Codec(encode: (wire) => {...wire, 'revision': 1}),
        _Codec(decode: (wire) => throw StateError('restricted-codec')),
        _Codec(decode: (wire) => proposed),
        _Codec(
          decode: (wire) =>
              _record(revision: 1, id: proposed.id, text: 'changed'),
        ),
        _Codec(decode: (wire) => _record(revision: 1)),
      ]) {
        final transport = _Transport((_, __) async => _reply({}));
        final repo = DynamoConditionalRepository<VersionedRecord>(
          _connect(transport),
          tableName: 'records',
          serializer: codec,
        );
        await expectLater(
          repo.save(proposed, precondition: const WritePrecondition.absent()),
          throwsA(
            isA<RepositoryCapabilityException>().having(
              (e) => e.toString(),
              'safe',
              isNot(contains('restricted')),
            ),
          ),
        );
        expect(transport.requests, isEmpty);
      }
    },
  );

  test(
    'no codec callback runs after the provider has accepted the write',
    () async {
      var accepted = false;
      final codec = _Codec(
        encode: (wire) {
          if (accepted) throw StateError('late codec');
          return wire;
        },
        decode: (wire) {
          if (accepted) throw StateError('late codec');
          return VersionedRecordJsonSerializer().fromJson(wire);
        },
      );
      final transport = _Transport((_, __) async {
        accepted = true;
        return _reply({});
      });
      final repo = DynamoConditionalRepository<VersionedRecord>(
        _connect(transport),
        tableName: 'records',
        serializer: codec,
      );
      final saved = await repo.save(
        _record(),
        precondition: const WritePrecondition.absent(),
      );
      expect(saved.revision, Revision(1));
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'actual SDK provider failures and lost response send once for save and delete',
    () async {
      for (final response in <http.StreamedResponse Function()>[
        () => _reply({
          '__type': 'InternalServerError',
          'message': 'restricted-server',
        }, 500),
        () => _reply({
          '__type': 'ProvisionedThroughputExceededException',
          'message': 'restricted-throttle',
        }, 400),
        () => http.StreamedResponse(
          Stream.error(http.ClientException('restricted-lost')),
          200,
        ),
      ]) {
        for (final deleting in [false, true]) {
          final transport = _Transport((_, __) async => response());
          final repo = ConditionalProbeDynamoRepository(
            _connect(transport),
            tableName: 'records',
          );
          final value = _record(revision: 1);
          final condition = WritePrecondition.atRevision(value.revision);
          await expectLater(
            deleting
                ? repo.deleteById(value.id, precondition: condition)
                : repo.save(value, precondition: condition),
            throwsA(
              isA<RepositoryException>()
                  .having((e) => e.cause, 'cause', isNull)
                  .having(
                    (e) => e.toString(),
                    'safe',
                    isNot(contains('restricted')),
                  ),
            ),
          );
          expect(transport.requests, hasLength(1));
        }
      }
    },
  );

  test(
    'delete capacity and invalid table names fail without SDK access',
    () async {
      final transport = _Transport((_, __) async => _reply({}));
      final connection = _connect(transport);
      for (final table in ['', 'ab', 'aws.reserved', '../records']) {
        expect(
          () => ConditionalProbeDynamoRepository(connection, tableName: table),
          throwsArgumentError,
        );
      }
      final repo = ConditionalProbeDynamoRepository(
        connection,
        tableName: 'records',
      );
      await expectLater(
        repo.deleteById(
          UuidValue.generate(),
          precondition: WritePrecondition.atRevision(
            Revision(Revision.maxValue),
          ),
        ),
        throwsA(isA<RevisionCapacityException>()),
      );
      expect(transport.requests, isEmpty);
    },
  );
}

class _Codec extends VersionedRecordJsonSerializer {
  _Codec({this.encode, this.decode});
  final Map<String, dynamic> Function(Map<String, dynamic>)? encode;
  final VersionedRecord Function(Map<String, dynamic>)? decode;
  @override
  Map<String, dynamic> toJson(
    VersionedRecord value, [
    SerializationConfig? config,
  ]) {
    final wire = super.toJson(value, config);
    return encode?.call(wire) ?? wire;
  }

  @override
  VersionedRecord fromJson(dynamic json, [SerializationConfig? config]) =>
      decode?.call(json as Map<String, dynamic>) ??
      super.fromJson(json, config);
}

class _WidenedVersioned extends legacy.TestUser
    implements VersionedAggregateRoot {
  _WidenedVersioned() : super(name: 'synthetic', email: 'synthetic');
  @override
  Revision get revision => const Revision.zero();
}
