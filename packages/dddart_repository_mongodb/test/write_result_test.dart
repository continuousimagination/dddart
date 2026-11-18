import 'package:dddart/dddart.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart';
// Construct driver response envelopes to inject acknowledgment failures.
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/abstract_write_result.dart';
import 'package:test/test.dart';

void main() {
  test('a write concern failure cannot become success or a revision conflict',
      () {
    final result = WriteResult.fromMap(WriteCommandType.update, {
      'ok': 1.0,
      'n': 1,
      'nModified': 1,
      'writeConcernError': {'code': 64, 'errmsg': 'acknowledgment timed out'},
    });
    expect(
      () => validateMongoWriteResult(
        result,
        id: UuidValue.generate(),
        expected: const ExpectedRevision.match('old'),
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
  });
  test('an unsuccessful command cannot be interpreted as zero matched rows',
      () {
    final result =
        WriteResult.fromMap(WriteCommandType.update, {'ok': 0.0, 'n': 0});
    expect(
      () => validateMongoWriteResult(result, id: UuidValue.generate()),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
  });
  test('write result failure prevents event publication and acknowledgment',
      () async {
    final aggregate = Probe()..raiseEvent(Changed());
    var published = false;
    await expectLater(
      saveWithEvents(
        aggregate: aggregate,
        persist: () async => validateMongoWriteResult(
          WriteResult.fromMap(WriteCommandType.update, {
            'ok': 1.0,
            'n': 1,
            'writeConcernError': {'code': 64, 'errmsg': 'uncertain'},
          }),
          id: aggregate.id,
        ),
        publisher: ProbePublisher(() {
          published = true;
        }),
      ),
      throwsA(isA<ConditionalWriteUncertainException>()),
    );
    expect(published, isFalse);
    expect(aggregate.getUncommittedEvents(), hasLength(1));
  });
}

class Probe extends AggregateRoot<UuidValue> {
  Probe() : super(id: UuidValue.generate());
}

class Changed extends DomainEvent<UuidValue, UuidValue> {
  Changed()
      : super(eventId: UuidValue.generate(), aggregateId: UuidValue.generate());
}

class ProbePublisher implements EventPublisher {
  ProbePublisher(this.onPublish);
  final void Function() onPublish;
  @override
  Future<bool> publish(DomainEvent<Identity, Identity> event) async {
    onPublish();
    return true;
  }
}
