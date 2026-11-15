// Test-only native browser entrypoint, independently loaded in each tab.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:html';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_indexeddb/dddart_repository_indexeddb.dart';
import 'package:idb_shim/idb_client_native.dart';

class _Sample extends UuidAggregateRoot {
  _Sample({required super.id, required this.name});

  final String name;
}

late IndexedDbRepository<_Sample, UuidValue> _repository;
final _prepared = <String, ConditionalCommit<_Sample, UuidValue>>{};
final _contextId = UuidValue.generate().uuid;

Map<String, Object?> _result(CommitResult<UuidValue> result) => {
      'operationId': result.operationId.uuid,
      'payloadDigest': result.payloadDigest,
      'decision': result.decision.name,
      'rejection': result.rejection?.name,
      'revisions': {
        for (final entry in result.revisions.entries)
          entry.key.uuid: entry.value,
      },
    };

Map<String, Object?> _snapshot(VersionedAggregate<_Sample, UuidValue> value) =>
    {
      'id': value.aggregate.id.uuid,
      'name': value.aggregate.name,
      'revision': value.revision,
    };

Future<Object?> _command(Map<String, dynamic> input) async {
  switch (input['command']) {
    case 'open':
      _repository = IndexedDbRepository<_Sample, UuidValue>(
        factory: idbFactoryNative,
        databaseName: input['database'] as String,
        storeName: 'samples',
        encode: (sample) => jsonEncode({
          'id': sample.id.uuid,
          'name': sample.name,
        }),
        decode: (encoded) {
          final data = jsonDecode(encoded) as Map<String, dynamic>;
          return _Sample(
            id: UuidValue.fromString(data['id'] as String),
            name: data['name'] as String,
          );
        },
      );
      // Force a real connection before the coordinator starts a race.
      try {
        await _repository.getVersioned(UuidValue.generate());
      } on RepositoryException catch (error) {
        if (error.type != RepositoryExceptionType.notFound) rethrow;
      }
      return {'contextId': _contextId, 'origin': window.location.origin};
    case 'read':
      return _snapshot(await _repository
          .getVersioned(UuidValue.fromString(input['id'] as String)));
    case 'unique':
      return _snapshot(await _repository
          .findUnique(UniqueValue('name', input['value'] as String)));
    case 'prepare':
      final operation = input['operation'] as Map<String, dynamic>;
      final request = ConditionalCommit<_Sample, UuidValue>(
        operationId: UuidValue.fromString(operation['operationId'] as String),
        mutations: [
          for (final item in operation['mutations'] as List<dynamic>)
            _mutation(item as Map<String, dynamic>),
        ],
      );
      final digest = _repository.digestFor(request);
      _prepared[request.operationId.uuid] = request;
      return {'payloadDigest': digest, 'contextId': _contextId};
    case 'commit':
      return _result(await _repository
          .commitConditional(_prepared[input['operationId']]!));
    case 'resolve':
      return _result(await _repository.resolveOperation(
        UuidValue.fromString(input['operationId'] as String),
        input['payloadDigest'] as String,
      ));
    case 'close':
      await _repository.close();
      return null;
    case 'deleteDatabase':
      await idbFactoryNative.deleteDatabase(input['database'] as String);
      return null;
    default:
      throw ArgumentError('Unknown command: ${input['command']}');
  }
}

ConditionalMutation<_Sample, UuidValue> _mutation(Map<String, dynamic> input) {
  final id = UuidValue.fromString(input['id'] as String);
  final revision = input['expected'] as String?;
  final expected = revision == null
      ? const ExpectedRevision.absent()
      : ExpectedRevision.match(revision);
  if (input['delete'] == true) {
    return ConditionalMutation.delete(id, expected: expected);
  }
  return ConditionalMutation.put(
    _Sample(id: id, name: input['name'] as String),
    expected: expected,
    uniqueValues: [
      if (input['unique'] != null)
        UniqueValue('name', input['unique'] as String),
    ],
  );
}

void main() {
  window.onMessage.listen((event) async {
    if (event.origin != window.location.origin || event.data is! String) return;
    final input = jsonDecode(event.data as String) as Map<String, dynamic>;
    if (input['direction'] != 'request') return;
    final response = <String, Object?>{
      'direction': 'response',
      'requestId': input['requestId'],
    };
    try {
      response['value'] = await _command(input);
    } on RepositoryException catch (error) {
      response['error'] = error.type.name;
    } catch (error, stack) {
      response['error'] = '$error\n$stack';
    }
    window.postMessage(jsonEncode(response), window.location.origin);
  });
  document.body!.dataset['ready'] = _contextId;
}
