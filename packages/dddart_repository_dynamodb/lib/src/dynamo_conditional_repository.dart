import 'dart:convert';
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_dynamodb/src/connection/dynamo_connection.dart';
import 'package:dddart_repository_dynamodb/src/exceptions/dynamo_repository_exception.dart';
import 'package:dddart_repository_dynamodb/src/utils/attribute_value_converter.dart';

/// Atomic conditional CRUD on a trusted dedicated DynamoDB table.
///
/// Never configure a legacy writable repository against this same mapping.
/// The trusted codec must round-trip one stable canonical JSON representation
/// with `id`, integer `revision`, `createdAt`, and `updatedAt` metadata. It must
/// create independent object graphs and must not mutate inputs or retain copies.
/// The reserved [retirementMarker] is owned exclusively by this repository.
class DynamoConditionalRepository<T extends VersionedAggregateRoot>
    implements ConditionalRepository<T> {
  /// Creates an adapter. All reads are strong; conditional writes never reread.
  DynamoConditionalRepository(
    this.connection, {
    required this.serializer,
    required this.tableName,
  }) {
    if (tableName.length < 3 ||
        tableName.length > 255 ||
        tableName.startsWith('aws.') ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(tableName)) {
      throw ArgumentError('Invalid dedicated table name.');
    }
  }

  /// Trusted connection, also available to custom generated repository methods.
  final DynamoConnection connection;

  /// Public canonical codec supplied by trusted composition.
  final JsonSerializer<T> serializer;

  /// Trusted dedicated mapping; never selected from an incoming aggregate.
  final String tableName;

  /// Reserved top-level metadata key; never valid in aggregate JSON.
  static const retirementMarker = '__dddart_retired';

  @override
  Future<T> getById(UuidValue id) async {
    try {
      final result = await connection.client.getItem(
        tableName: tableName,
        key: {'id': AttributeValue(s: id.uuid)},
        consistentRead: true,
      );
      final item = result.item;
      if (item == null || item.isEmpty) {
        throw const RepositoryException(
          'Aggregate not found.',
          type: RepositoryExceptionType.notFound,
        );
      }
      final wire = AttributeValueConverter.attributeMapToJsonMap(item);
      if (wire['id'] != id.uuid ||
          wire['revision'] is! int ||
          (wire['revision'] as int) <= 0) {
        throw const RepositoryCapabilityException();
      }
      Revision(wire['revision'] as int);
      if (wire.containsKey(retirementMarker)) {
        if (wire[retirementMarker] != true || wire.length != 3) {
          throw const RepositoryCapabilityException();
        }
        throw const RepositoryException(
          'Aggregate not found.',
          type: RepositoryExceptionType.notFound,
        );
      }
      final value = serializer.fromJson(_detach(wire));
      if (value.id != id || !_same(wire, _wire(value))) {
        throw const RepositoryCapabilityException();
      }
      return value;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw DynamoRepositoryException.map(error, 'getById');
    }
  }

  @override
  Future<T> save(T proposed, {required WritePrecondition precondition}) async {
    final expected = switch (precondition) {
      AbsentWritePrecondition() => const Revision.zero(),
      RevisionWritePrecondition(:final revision) => revision,
    };
    if (proposed.revision != expected) {
      throw ArgumentError('Proposal revision must match its precondition.');
    }
    final next = expected.next();
    late final T accepted;
    late final Map<String, AttributeValue> item;
    try {
      final wire = _wire(proposed);
      final advanced = {...wire, 'revision': next.value};
      accepted = serializer.fromJson(_detach(advanced));
      if (identical(accepted, proposed) || !_same(advanced, _wire(accepted))) {
        throw const RepositoryCapabilityException();
      }
      item = AttributeValueConverter.jsonMapToAttributeMap(_detach(advanced));
    } on RepositoryCapabilityException {
      rethrow;
    } catch (_) {
      throw const RepositoryCapabilityException();
    }
    try {
      if (expected.value == 0) {
        await connection.client.putItem(
          tableName: tableName,
          item: item,
          conditionExpression: 'attribute_not_exists(#id)',
          expressionAttributeNames: {'#id': 'id'},
        );
      } else {
        await _replace(item, expected);
      }
      // No post-write codec call or reread can manufacture another snapshot.
      return accepted;
    } on ConditionalCheckFailedException {
      throw const PreconditionFailedException();
    } catch (error) {
      throw DynamoRepositoryException.map(error, 'save');
    }
  }

  @override
  Future<void> deleteById(
    UuidValue id, {
    required WritePrecondition precondition,
  }) async {
    if (precondition is! RevisionWritePrecondition) {
      throw ArgumentError('Retirement requires a positive expected revision.');
    }
    final expected = precondition.revision;
    final next = expected.next();
    try {
      await _replace({
        'id': AttributeValue(s: id.uuid),
        'revision': AttributeValue(n: next.value.toString()),
        retirementMarker: AttributeValue(boolValue: true),
      }, expected);
    } on ConditionalCheckFailedException {
      throw const PreconditionFailedException();
    } catch (error) {
      throw DynamoRepositoryException.map(error, 'deleteById');
    }
  }

  Future<void> _replace(
    Map<String, AttributeValue> item,
    Revision expected,
  ) async {
    await connection.client.putItem(
      tableName: tableName,
      item: item,
      conditionExpression:
          'attribute_exists(#id) AND #revision = :expected AND attribute_not_exists(#retired)',
      expressionAttributeNames: {
        '#id': 'id',
        '#revision': 'revision',
        '#retired': retirementMarker,
      },
      expressionAttributeValues: {
        ':expected': AttributeValue(n: expected.value.toString()),
      },
    );
  }

  Map<String, dynamic> _wire(T value) {
    final wire = _detach(serializer.toJson(value));
    if (wire.containsKey(retirementMarker) ||
        wire['id'] != value.id.uuid ||
        wire['revision'] is! int ||
        wire['revision'] != value.revision.value ||
        wire['createdAt'] != value.createdAt.toIso8601String() ||
        wire['updatedAt'] != value.updatedAt.toIso8601String()) {
      throw const RepositoryCapabilityException();
    }
    return wire;
  }

  Map<String, dynamic> _detach(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
    }
    return a == b;
  }
}
