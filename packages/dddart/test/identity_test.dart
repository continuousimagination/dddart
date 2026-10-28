import 'dart:io';

import 'package:dddart/dddart.dart';
import 'package:test/test.dart';

class _IssueId extends Identity {
  const _IssueId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class _OtherId extends Identity {
  const _OtherId(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class _ScopedIssueId extends Identity {
  const _ScopedIssueId(this.repository, this.number);
  final String repository;
  final int number;
  @override
  List<Object?> get props => [repository, number];
}

class _Issue<I extends Identity> extends AggregateRoot<I> {
  _Issue({required super.id});
}

class _Raised<I extends Identity> extends DomainEvent<I> {
  _Raised({required super.aggregateId});
}

class _UuidAggregate extends UuidAggregateRoot {
  _UuidAggregate({super.id});
}

class _UuidEntity extends UuidEntity {
  _UuidEntity({super.id});
}

void main() {
  test('identity equality and hashing preserve kind and immutable values', () {
    const id = _IssueId('github-assigned');
    const equal = _IssueId('github-assigned');
    expect(id, equal);
    expect(id.hashCode, equal.hashCode);
    final identities = <Identity>{}
      ..add(id)
      ..add(equal)
      ..add(const _OtherId('github-assigned'));
    expect(identities, hasLength(2));
    expect(const _IssueId('IssueA'), isNot(const _IssueId('issuea')));
    expect(const _IssueId('different'), isNot(id));
  });

  test('native string identity flows through aggregate, repository and event',
      () async {
    final issue = _Issue(id: const _IssueId('github-native-123'));
    final Repository<_Issue<_IssueId>, _IssueId> repository =
        InMemoryRepository<_Issue<_IssueId>, _IssueId>();
    await repository.save(issue);
    final loaded =
        await repository.getById(const _IssueId('github-native-123'));
    expect(loaded, same(issue));
    final event = _Raised(aggregateId: loaded.id);
    issue.raiseEvent(event);
    final pending = issue.getUncommittedEvents();
    expect(pending.single.aggregateId, issue.id);
    expect(pending.single.eventId, isA<UuidValue>());
    await repository.deleteById(issue.id);
    await expectLater(
      repository.getById(issue.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('scoped IDs with equal local numbers coexist and delete independently',
      () async {
    const firstId = _ScopedIssueId('org/one', 12);
    const secondId = _ScopedIssueId('org/two', 12);
    final first = _Issue(id: firstId);
    final second = _Issue(id: secondId);
    final repository =
        InMemoryRepository<_Issue<_ScopedIssueId>, _ScopedIssueId>();
    await repository.save(first);
    await repository.save(second);
    expect(
      await repository.getById(const _ScopedIssueId('org/one', 12)),
      same(first),
    );
    expect(await repository.getById(secondId), same(second));
    expect(<_ScopedIssueId>{firstId, secondId}, hasLength(2));
    await repository.deleteById(firstId);
    expect(await repository.getById(secondId), same(second));
  });

  test('case-sensitive IDs coexist in the in-memory repository', () async {
    final repository = InMemoryRepository<_Issue<_IssueId>, _IssueId>();
    final upper = _Issue(id: const _IssueId('IssueA'));
    final lower = _Issue(id: const _IssueId('issuea'));
    await repository.save(upper);
    await repository.save(lower);
    expect(await repository.getById(upper.id), same(upper));
    expect(await repository.getById(lower.id), same(lower));
    await repository.deleteById(upper.id);
    expect(await repository.getById(lower.id), same(lower));
  });

  test('UUID generation and explicit UUID convenience remain available',
      () async {
    final entity = _UuidEntity();
    final aggregate = _UuidAggregate();
    expect(entity.id, isA<Identity>());
    expect(aggregate.id, isA<UuidValue>());
    expect(_UuidEntity(id: entity.id).id, entity.id);
    expect(_UuidAggregate(id: aggregate.id).id, aggregate.id);
    expect(UuidValue.fromString(entity.id.uuid), entity.id);
    expect(() => UuidValue.fromString('github-native'), throwsArgumentError);
    final repository = InMemoryRepository<_UuidAggregate, UuidValue>();
    await repository.save(aggregate);
    expect(await repository.getById(aggregate.id), same(aggregate));
  });

  test('one event bus carries typed references for heterogeneous identities',
      () async {
    final bus = EventBus();
    final received = bus.on<_Raised<_IssueId>>().first;
    bus.publish(_Raised(aggregateId: UuidValue.generate()));
    final event = _Raised(aggregateId: const _IssueId('native'));
    bus.publish(event);
    expect(await received, same(event));
    await bus.close();
  });

  test(
    'compiler rejects unrelated ID types and missing external identity',
    () async {
      final directory = Directory.systemTemp.createTempSync('identity_types_');
      try {
        var current = Directory.current.absolute;
        while (!File('${current.path}/.dart_tool/package_config.json')
            .existsSync()) {
          if (current.parent.path == current.path) {
            throw StateError('No package configuration');
          }
          current = current.parent;
        }
        final packageConfig = '${current.path}/.dart_tool/package_config.json';
        const declarations = '''
import 'package:dddart/dddart.dart';
class IssueId extends Identity {
  const IssueId(this.value);
  final String value;
  @override List<Object?> get props => [value];
}
class OtherId extends Identity {
  const OtherId(this.value);
  final String value;
  @override List<Object?> get props => [value];
}
class Issue extends AggregateRoot<IssueId> { Issue({required super.id}); }
class OtherEvent extends DomainEvent<OtherId> { OtherEvent({required super.aggregateId}); }
''';
        Future<ProcessResult> compile(String statement) async {
          final source = File('${directory.path}/probe.dart')
            ..writeAsStringSync('''
$declarations
void main() {
  final issue = Issue(id: const IssueId('native'));
  final repository = InMemoryRepository<Issue, IssueId>();
  repository.save(issue);
  $statement
}
''');
          return Process.run(Platform.resolvedExecutable, [
            '--suppress-analytics',
            'compile',
            'kernel',
            '--packages=$packageConfig',
            source.path,
            '-o',
            '${directory.path}/probe.dill',
          ]);
        }

        final positive =
            await compile("repository.getById(const IssueId('native'));");
        expect(
          positive.exitCode,
          0,
          reason: '${positive.stdout}\n${positive.stderr}',
        );
        for (final statement in [
          "repository.getById(const OtherId('wrong'));",
          "repository.deleteById(const OtherId('wrong'));",
          "issue.raiseEvent(OtherEvent(aggregateId: const OtherId('wrong')));",
          'InMemoryRepository<Issue, OtherId>();',
          'Issue();',
        ]) {
          final negative = await compile(statement);
          expect(negative.exitCode, isNot(0), reason: statement);
          expect(
            '${negative.stdout}\n${negative.stderr}',
            contains('Error:'),
            reason: statement,
          );
        }
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
