import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'a clean event consumer generates, round-trips and rejects erased or wrong identity types',
    () async {
      final packageRoot = Directory.current.absolute;
      final packagesRoot = packageRoot.parent;
      final fixture =
          Directory.systemTemp.createTempSync('dddart_event_consumer_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: clean_event_consumer
publish_to: none
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
  dddart: any
  dddart_json: any
  dddart_serialization: any
  dddart_events_distributed:
    path: ${packageRoot.path}
dev_dependencies:
  build_runner: ^2.4.0
dependency_overrides:
  dddart:
    path: ${packagesRoot.path}/dddart
  dddart_json:
    path: ${packagesRoot.path}/dddart_json
  dddart_serialization:
    path: ${packagesRoot.path}/dddart_serialization
''');
      final lib = Directory('${fixture.path}/lib')..createSync();
      final input = File('${lib.path}/events.dart');
      final source = '''
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
__GENERATED_PART_DIRECTIVE__

class RemoteId extends Identity {
  const RemoteId(this.value);
  final String value;
  @override List<Object?> get props => [value];
}
class RemoteCodec implements IdentityCodec<RemoteId> {
  @override Object toJson(RemoteId id) => {'remote':id.value};
  @override RemoteId fromJson(Object? json) => RemoteId((json as Map)['remote'] as String);
  @override String toKey(RemoteId id) => id.value;
  @override RemoteId fromKey(String key) => RemoteId(key);
}
@Serializable()
@DistributedEvent('remote.issue.opened.v1')
class RemoteIssueOpened extends DomainEvent<RemoteId> {
  RemoteIssueOpened({required super.aggregateId,required this.title,super.eventId,super.occurredAt,super.context});
  final String title;
}
'''.replaceFirst('__GENERATED_PART_DIRECTIVE__', "part 'events.g.dart';");
      input.writeAsStringSync(source);
      Directory('${fixture.path}/bin').createSync();
      File('${fixture.path}/bin/main.dart').writeAsStringSync('''
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:clean_event_consumer/events.dart';
void main() {
  final identities=IdentityCodecRegistry()..register<RemoteId>('remote',RemoteCodec());
  final registry=createGeneratedEventRegistry(identityCodecs:identities);
  final event=RemoteIssueOpened(aggregateId:const RemoteId('Repo/IssueA %2F, café'),title:'created',context:{'tenantId':'one'});
  final stored=StoredEvent<RemoteId>.fromDomainEvent(event,registry:registry);
  final restored=StoredEvent<RemoteId>.fromJson(stored.toJson(),identityCodecs:identities).restore(registry) as RemoteIssueOpened;
  if(restored.aggregateId!=event.aggregateId || restored.eventId!=event.eventId || restored.title!=event.title || restored.context['tenantId']!='one' || stored.eventType!='remote.issue.opened.v1') throw StateError('Lost event data');
}
''');
      await _success(fixture, ['pub', 'get', '--offline']);
      await _success(
        fixture,
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      );
      expect(File('${lib.path}/events.g.dart').existsSync(), isTrue);
      await _success(fixture, ['analyze', '--fatal-infos']);
      await _success(fixture, [
        'compile',
        'kernel',
        'bin/main.dart',
        '-o',
        '${fixture.path}/main.dill',
      ]);
      await _success(fixture, ['run', 'bin/main.dart']);
      final wrong = File('${lib.path}/wrong.dart')..writeAsStringSync('''
import 'package:dddart/dddart.dart';
import 'events.dart';
void wrongIdentity() {
  RemoteIssueOpened(aggregateId:UuidValue.generate(),title:'wrong');
}
''');
      final negative =
          await _dart(fixture, ['analyze', '--fatal-infos', 'lib/wrong.dart']);
      expect(negative.exitCode, isNot(0));
      expect(
        '${negative.stdout}${negative.stderr}',
        contains('argument_type_not_assignable'),
      );
      wrong.deleteSync();
      input.writeAsStringSync('''
$source
@Serializable()
class ErasedEvent extends DomainEvent<Identity> {
  ErasedEvent({required super.aggregateId,super.eventId,super.occurredAt,super.context});
}
''');
      final erased = await _dart(
        fixture,
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      );
      expect(erased.exitCode, isNot(0));
      expect('${erased.stdout}${erased.stderr}', contains('concrete'));
      input.writeAsStringSync('''
$source
@Serializable()
@DistributedEvent('remote.issue.opened.v1')
class OtherEvent extends DomainEvent<UuidValue> {
  OtherEvent({required super.aggregateId,super.eventId,super.occurredAt,super.context});
}
''');
      final duplicate = await _dart(
        fixture,
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      );
      expect(duplicate.exitCode, isNot(0));
      expect(
        '${duplicate.stdout}${duplicate.stderr}',
        contains('Duplicate or invalid distributed event key'),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<ProcessResult> _dart(Directory directory, List<String> arguments) =>
    Process.run(
      Platform.resolvedExecutable,
      arguments,
      workingDirectory: directory.path,
      environment: {...Platform.environment, 'CI': 'true'},
    );
Future<void> _success(Directory directory, List<String> arguments) async {
  final result = await _dart(directory, arguments);
  expect(
    result.exitCode,
    0,
    reason: 'dart $arguments\n${result.stdout}\n${result.stderr}',
  );
}
