import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'external consumer uses HTTP and AppSync through one public client API',
    () async {
      final packages = Directory.current.absolute.parent;
      final fixture =
          Directory.systemTemp.createTempSync('dddart_transport_consumer_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: transport_consumer
publish_to: none
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
  dddart: any
  dddart_events_distributed: any
  dddart_events_appsync: any
dependency_overrides:
${[
        'dddart',
        'dddart_serialization',
        'dddart_json',
        'dddart_events_distributed',
        'dddart_events_appsync',
      ].map((name) => '  $name:\n    path: ${packages.path}/$name').join('\n')}
''');
      Directory('${fixture.path}/bin').createSync();
      File('${fixture.path}/bin/main.dart').writeAsStringSync('''
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/dddart_events_distributed.dart';
import 'package:dddart_events_appsync/dddart_events_appsync.dart';
Future<void> exercise(AggregateEventTransport transport, EventRegistry registry) async {
  final client=AggregateEventClient(transport:transport,registry:registry,aggregateKind:(_) => 'issue');
  final EventPublisher publisher=client.publisher;
  if (publisher is! EnvelopeEventPublisher) throw StateError('Different publisher contract');
  await client.close();
}
Future<void> main() async {
  final registry=EventRegistry();
  final wire=AggregateEventWire(registry.identityCodecs);
  HttpAggregateEventTransport http() => HttpAggregateEventTransport(
    baseUrl:Uri.parse('http://127.0.0.1:1/events'),wire:wire,tokenProvider:() async => null);
  await exercise(http(), registry);
  final LiveAggregateEventTransport live=AppSyncEventTransport(
    httpEndpoint:Uri.parse('https://example.appsync-api.test/event'),
    realtimeEndpoint:Uri.parse('wss://example.appsync-realtime-api.test/event/realtime'),
    namespace:'aggregates',control:http(),wire:wire,authorization:() async => <String,String>{});
  await exercise(live, registry);
}
''');
      for (final arguments in <List<String>>[
        ['pub', 'get', '--offline'],
        ['analyze', '--fatal-infos'],
        [
          'compile',
          'kernel',
          'bin/main.dart',
          '-o',
          '${fixture.path}/main.dill',
        ],
        ['run', 'bin/main.dart'],
      ]) {
        final result = await Process.run(
          Platform.resolvedExecutable,
          arguments,
          workingDirectory: fixture.path,
        );
        expect(
          result.exitCode,
          0,
          reason: 'dart $arguments\n${result.stdout}\n${result.stderr}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
