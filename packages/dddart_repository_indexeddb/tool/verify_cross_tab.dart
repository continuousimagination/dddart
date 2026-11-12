import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dddart/dddart.dart';

/// Runs native IndexedDB operations in independently loaded same-origin pages.
///
/// No Node, WebDriver, popup permission, or browser automation package is needed.
Future<void> main(List<String> arguments) async {
  if (arguments.length > 1 ||
      (arguments.isNotEmpty && int.tryParse(arguments.single) == null)) {
    throw ArgumentError('Usage: dart tool/verify_cross_tab.dart [race-rounds]');
  }
  final rounds = arguments.isEmpty ? 10 : int.parse(arguments.single);
  if (rounds < 1) throw ArgumentError('race-rounds must be positive');
  final package = File.fromUri(Platform.script).parent.parent;
  final root = package.parent.parent;
  final temporary = Directory.systemTemp.createTempSync('dddart_cross_tab_');
  HttpServer? server;
  Process? browser;
  _Cdp? cdp;
  final diagnostics = StringBuffer();
  try {
    final compiled = await Process.run(
        Platform.resolvedExecutable,
        [
          'compile',
          'js',
          '${package.path}/tool/cross_tab_participant.dart',
          '-o',
          '${temporary.path}/participant.js',
        ],
        workingDirectory: root.path);
    stderr.write(compiled.stdout);
    stderr.write(compiled.stderr);
    _check(compiled.exitCode == 0, 'participant compilation');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/participant.js') {
        request.response.headers.contentType =
            ContentType('text', 'javascript');
        await request.response.addStream(
          File('${temporary.path}/participant.js').openRead(),
        );
      } else if (request.uri.path == '/') {
        request.response.headers.contentType = ContentType.html;
        request.response
            .write('<!doctype html><title>IndexedDB participant</title>'
                '<body><script defer src="/participant.js"></script></body>');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final executable = Platform.environment['CHROME_EXECUTABLE'] ??
        (Platform.isMacOS
            ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
            : 'google-chrome');
    browser = await Process.start(executable, [
      '--headless=new',
      '--disable-dev-shm-usage',
      '--no-first-run',
      '--no-default-browser-check',
      '--remote-debugging-port=0',
      '--user-data-dir=${temporary.path}/profile',
      'about:blank',
    ]);
    final endpoint = Completer<String>();
    unawaited(browser.stdout.drain<void>());
    browser.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      diagnostics.writeln(line);
      if (line.startsWith('DevTools listening on ') && !endpoint.isCompleted) {
        endpoint.complete(line.substring('DevTools listening on '.length));
      }
    });
    unawaited(browser.exitCode.then((code) {
      if (!endpoint.isCompleted) {
        endpoint.completeError(StateError('Chrome exited $code: $diagnostics'));
      }
    }));
    cdp = _Cdp(await WebSocket.connect(
      await endpoint.future.timeout(const Duration(seconds: 30)),
    ));
    final version = await cdp.send('Browser.getVersion');
    final url = 'http://127.0.0.1:${server.port}/';
    final database = 'dddart-cross-tab-${UuidValue.generate()}';
    final harness = _Harness(cdp, url, database);
    final results = await harness.run(rounds);
    final git = await Process.run('git', ['rev-parse', 'HEAD'],
        workingDirectory: root.path);
    final status = await Process.run('git', ['status', '--porcelain'],
        workingDirectory: root.path);
    _check(git.exitCode == 0 && status.exitCode == 0, 'Git revision evidence');
    final sourcePaths = [
      'packages/dddart/pubspec.yaml',
      'packages/dddart_serialization/pubspec.yaml',
      'packages/dddart_repository_indexeddb/pubspec.yaml',
      for (final name in [
        'dddart',
        'dddart_serialization',
        'dddart_repository_indexeddb'
      ])
        ...Directory('${root.path}/packages/$name/lib')
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path.substring(root.path.length + 1)),
      'packages/dddart_repository_indexeddb/tool/cross_tab_participant.dart',
      'packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart',
    ]..sort();
    final sourceHashes = {
      for (final path in sourcePaths)
        path: sha256
            .convert(File('${root.path}/$path').readAsBytesSync())
            .toString(),
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'result': 'PASS',
      'browser': version,
      'dartVersion': Platform.version,
      'baseSha': (git.stdout as String).trim(),
      'workingTreeStatus': (status.stdout as String).trim(),
      'sourceManifestSha256':
          sha256.convert(utf8.encode(jsonEncode(sourceHashes))).toString(),
      'sourceHashes': sourceHashes,
      'rounds': rounds,
      ...results,
      'independentReview': 'Worky-owned; not asserted by this test',
    }));
  } catch (_) {
    stderr.write(diagnostics);
    rethrow;
  } finally {
    if (cdp != null) {
      try {
        await cdp.send('Browser.close');
      } catch (_) {
        // Chrome can close the socket before acknowledging Browser.close.
      }
      await cdp.close();
    }
    if (browser != null) {
      browser.kill();
      await browser.exitCode;
    }
    await server?.close(force: true);
    temporary.deleteSync(recursive: true);
  }
}

void _check(bool condition, String label) {
  if (!condition) throw StateError('FAIL: $label');
}

class _Cdp {
  _Cdp(this.socket) {
    socket.listen((dynamic event) {
      final message = jsonDecode(event as String) as Map<String, dynamic>;
      if (message['id'] == null) {
        _events.add(message);
        return;
      }
      final pending = _pending.remove(message['id']);
      if (pending == null) return;
      if (message['error'] != null) {
        pending.completeError(StateError('CDP: ${message['error']}'));
      } else {
        pending.complete(message['result'] as Map<String, dynamic>);
      }
    }, onDone: () {
      for (final pending in _pending.values) {
        pending.completeError(StateError('Chrome connection closed'));
      }
      _pending.clear();
      unawaited(_events.close());
    });
  }

  final WebSocket socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;

  Future<Map<String, dynamic>> send(
    String method, {
    Map<String, Object?> params = const {},
    String? session,
  }) {
    final id = ++_nextId;
    final result = Completer<Map<String, dynamic>>();
    _pending[id] = result;
    socket.add(jsonEncode({
      'id': id,
      'method': method,
      'params': params,
      if (session != null) 'sessionId': session,
    }));
    return result.future.timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> event(String method, String session) => _events
      .stream
      .firstWhere(
          (event) => event['method'] == method && event['sessionId'] == session)
      .timeout(const Duration(seconds: 30));

  Future<void> close() async => socket.close();
}

class _Tab {
  _Tab(this.cdp, this.target, this.session);

  final _Cdp cdp;
  final String target;
  final String session;
  int _sequence = 0;

  Future<Object?> evaluate(String expression) async {
    final response =
        await cdp.send('Runtime.evaluate', session: session, params: {
      'expression': expression,
      'awaitPromise': true,
      'returnByValue': true,
    });
    _check(response['exceptionDetails'] == null,
        'browser evaluation: ${response['exceptionDetails']}');
    return (response['result'] as Map<String, dynamic>)['value'];
  }

  Future<Map<String, dynamic>> command(
    String command, {
    Map<String, Object?> args = const {},
    String? expectedError,
  }) async {
    final request = jsonEncode(jsonEncode({
      'direction': 'request',
      'requestId': ++_sequence,
      'command': command,
      ...args,
    }));
    final result = await evaluate('''new Promise(resolve => {
      const request = JSON.parse($request);
      const listener = event => {
        if (event.source !== window || event.origin !== location.origin ||
            typeof event.data !== 'string') return;
        const response = JSON.parse(event.data);
        if (response.direction !== 'response' ||
            response.requestId !== request.requestId) return;
        window.removeEventListener('message', listener);
        resolve(response);
      };
      window.addEventListener('message', listener);
      window.postMessage($request, location.origin);
    })''') as Map<String, dynamic>;
    _check(result['error'] == expectedError,
        '$command error: ${result['error']} (expected $expectedError)');
    return (result['value'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> close() async {
    await command('close');
    await cdp.send('Target.closeTarget', params: {'targetId': target});
  }
}

class _Operation {
  _Operation(this.request, this.digest, this.result);
  final Map<String, Object?> request;
  final String digest;
  final Map<String, dynamic> result;
}

class _Harness {
  _Harness(this.cdp, this.url, this.database);
  final _Cdp cdp;
  final String url;
  final String database;
  final operations = <_Operation>[];
  final contexts = <String>[];
  final targets = <String>[];

  Future<_Tab> open() async {
    // Target.createTarget creates an actual top-level page, not an iframe,
    // worker, second connection in one isolate, or separate storage partition.
    final created =
        await cdp.send('Target.createTarget', params: {'url': 'about:blank'});
    final target = created['targetId'] as String;
    final attached = await cdp.send('Target.attachToTarget', params: {
      'targetId': target,
      'flatten': true,
    });
    final tab = _Tab(cdp, target, attached['sessionId'] as String);
    await cdp.send('Page.enable', session: tab.session);
    // Subscribe before explicit navigation, so readiness is never awaited in
    // the initial about:blank document or lost during a document replacement.
    final loaded = cdp.event('Page.loadEventFired', tab.session);
    await cdp.send('Page.navigate', session: tab.session, params: {'url': url});
    await loaded;
    final ready = await tab.evaluate('document.body.dataset.ready');
    _check(ready is String && ready.isNotEmpty, 'participant initialized');
    final info =
        await cdp.send('Target.getTargetInfo', params: {'targetId': target});
    _check((info['targetInfo'] as Map)['type'] == 'page', 'top-level page');
    final identity = await tab.command('open', args: {'database': database});
    _check(
        identity['origin'] == url.substring(0, url.length - 1), 'same origin');
    _check(
        !contexts.contains(identity['contextId']), 'independent Dart context');
    contexts.add(identity['contextId'] as String);
    targets.add(target);
    return tab;
  }

  Map<String, Object?> put(
    String id,
    String name, {
    String? expected,
    String? unique,
  }) =>
      {'id': id, 'name': name, 'expected': expected, 'unique': unique};

  Map<String, Object?> request(List<Map<String, Object?>> mutations) => {
        'operationId': UuidValue.generate().uuid,
        'mutations': mutations,
      };

  Future<String> prepare(_Tab tab, Map<String, Object?> request) async =>
      (await tab.command('prepare',
          args: {'operation': request}))['payloadDigest'] as String;

  Future<_Operation> commit(_Tab tab, Map<String, Object?> request) async {
    final digest = await prepare(tab, request);
    final result = await tab.command('commit', args: {
      'operationId': request['operationId'],
    });
    _check(result['payloadDigest'] == digest, 'precomputed payload digest');
    final operation = _Operation(request, digest, result);
    operations.add(operation);
    return operation;
  }

  Future<List<_Operation>> race(_Tab a, _Tab b, Map<String, Object?> left,
      Map<String, Object?> right) async {
    // Both independent contexts finish staging before either is dispatched.
    // There is no coordinator lock around either IndexedDB commit.
    final digests = await Future.wait([prepare(a, left), prepare(b, right)]);
    final results = await Future.wait([
      a.command('commit', args: {'operationId': left['operationId']}),
      b.command('commit', args: {'operationId': right['operationId']}),
    ]);
    _check(results.where((r) => r['decision'] == 'committed').length == 1,
        'exactly one committed writer');
    _check(results.where((r) => r['decision'] == 'rejected').length == 1,
        'exactly one rejected writer');
    final pair = [
      _Operation(left, digests[0], results[0]),
      _Operation(right, digests[1], results[1]),
    ];
    for (final operation in pair) {
      _check(operation.result['payloadDigest'] == operation.digest,
          'race payload digest');
    }
    operations.addAll(pair);
    return pair;
  }

  Future<Map<String, dynamic>> read(_Tab tab, String id) =>
      tab.command('read', args: {'id': id});

  void receipt(Map<String, dynamic> actual, _Operation original) {
    _check(jsonEncode(actual) == jsonEncode(original.result),
        'identical durable outcome for ${original.request['operationId']}');
  }

  Future<Map<String, Object?>> run(int rounds) async {
    var a = await open();
    var b = await open();
    final id = UuidValue.generate().uuid;
    final initial = await commit(a, request([put(id, 'Original')]));
    _check(initial.result['decision'] == 'committed', 'initial creation');
    final uniqueSnapshots = <String, Map<String, dynamic>>{};
    final absentIds = <String>[];
    late _Operation lastUniqueWinner;
    late String lastUniqueOwner;
    for (var round = 0; round < rounds; round++) {
      final before = await Future.wait([read(a, id), read(b, id)]);
      _check(
          before[0]['revision'] == before[1]['revision'], 'same read revision');
      final pair = await race(
        a,
        b,
        request([
          put(id, 'Left-$round', expected: before[0]['revision'] as String)
        ]),
        request([
          put(id, 'Right-$round', expected: before[1]['revision'] as String)
        ]),
      );
      final winner =
          pair.singleWhere((op) => op.result['decision'] == 'committed');
      final loser =
          pair.singleWhere((op) => op.result['decision'] == 'rejected');
      _check(loser.result['rejection'] == 'staleRevision',
          'stale revision rejection');
      final winningMutation =
          (winner.request['mutations'] as List).single as Map;
      for (final tab in [a, b]) {
        final snapshot = await read(tab, id);
        _check(
            snapshot['name'] == winningMutation['name'] &&
                snapshot['revision'] == (winner.result['revisions'] as Map)[id],
            'winning snapshot and revision visible across tabs');
        receipt(
            await tab.command('resolve', args: {
              'operationId': loser.request['operationId'],
              'payloadDigest': loser.digest,
            }),
            loser);
      }
      final claimIds = [UuidValue.generate().uuid, UuidValue.generate().uuid];
      final unique = 'shared-$round';
      final claims = await race(
        b,
        a,
        request([put(claimIds[0], 'Claim-left-$round', unique: unique)]),
        request([put(claimIds[1], 'Claim-right-$round', unique: unique)]),
      );
      final owner =
          claims.singleWhere((op) => op.result['decision'] == 'committed');
      final rejected =
          claims.singleWhere((op) => op.result['decision'] == 'rejected');
      _check(
          rejected.result['rejection'] == 'uniqueConflict', 'unique rejection');
      final ownerId = (owner.result['revisions'] as Map).keys.single as String;
      final missingId = claimIds.singleWhere((value) => value != ownerId);
      absentIds.add(missingId);
      uniqueSnapshots[unique] = await read(a, ownerId);
      for (final tab in [a, b]) {
        final found = await tab.command('unique', args: {'value': unique});
        _check(
            found['id'] == ownerId &&
                found['revision'] ==
                    (owner.result['revisions'] as Map)[ownerId],
            'single consistent owner');
        _check(jsonEncode(found) == jsonEncode(await read(tab, ownerId)),
            'unique lookup matches record');
        await tab.command('read',
            args: {'id': missingId}, expectedError: 'notFound');
      }
      lastUniqueWinner = owner;
      lastUniqueOwner = ownerId;
    }

    // Remove the last owner. Its losing request would succeed if re-evaluated;
    // the durable rejection must still win over these newly available conditions.
    final release = await commit(
        a,
        request([
          {
            'id': lastUniqueOwner,
            'delete': true,
            'expected':
                (lastUniqueWinner.result['revisions'] as Map)[lastUniqueOwner],
          }
        ]));
    _check(release.result['decision'] == 'committed', 'release unique owner');
    uniqueSnapshots.remove('shared-${rounds - 1}');
    absentIds.add(lastUniqueOwner);

    // B retains an old revision while A deletes and recreates the same identity.
    final old = await read(b, id);
    final staleRequest =
        request([put(id, 'Stale ABA', expected: old['revision'] as String)]);
    final staleDigest = await prepare(b, staleRequest);
    final deleted = await commit(
        a,
        request([
          {
            'id': id,
            'delete': true,
            'expected': old['revision'],
          }
        ]));
    _check(deleted.result['decision'] == 'committed', 'ABA delete');
    final recreated = await commit(a, request([put(id, 'Recreated')]));
    _check(recreated.result['decision'] == 'committed', 'ABA recreate');
    _check((recreated.result['revisions'] as Map)[id] != old['revision'],
        'new incarnation revision');
    final staleResult = await b.command('commit', args: {
      'operationId': staleRequest['operationId'],
    });
    _check(staleResult['rejection'] == 'staleRevision',
        'cross-context ABA blocked');
    _check(
        staleResult['payloadDigest'] == staleDigest, 'ABA precomputed digest');
    operations.add(_Operation(staleRequest, staleDigest, staleResult));
    final finalSnapshot = await read(a, id);
    _check(finalSnapshot['name'] == 'Recreated', 'ABA preserved recreation');

    // Destroy both pages (not merely their repository objects) and reopen them.
    // Only the coordinator retains the exact serialized request and digest.
    await a.close();
    await b.close();
    a = await open();
    b = await open();
    for (final operation in operations) {
      receipt(
          await a.command('resolve', args: {
            'operationId': operation.request['operationId'],
            'payloadDigest': operation.digest,
          }),
          operation);
      _check(await prepare(b, operation.request) == operation.digest,
          'identical digest after page recreation');
      receipt(
          await b.command('commit', args: {
            'operationId': operation.request['operationId'],
          }),
          operation);
    }
    _check(jsonEncode(await read(a, id)) == jsonEncode(finalSnapshot),
        'retries do not overwrite newer incarnation or allocate revisions');
    for (final tab in [a, b]) {
      for (final missingId in absentIds) {
        await tab.command('read',
            args: {'id': missingId}, expectedError: 'notFound');
      }
      for (final entry in uniqueSnapshots.entries) {
        _check(
            jsonEncode(await read(tab, entry.value['id'] as String)) ==
                jsonEncode(entry.value),
            'unchanged unique owner after replay');
        _check(
            jsonEncode(
                    await tab.command('unique', args: {'value': entry.key})) ==
                jsonEncode(entry.value),
            'unchanged unique index after replay');
      }
      await tab.command('unique',
          args: {'value': 'shared-${rounds - 1}'}, expectedError: 'notFound');
    }
    final changed = {
      'operationId': initial.request['operationId'],
      'mutations': [put(id, 'Changed payload')],
    };
    _check(
        await prepare(b, changed) != initial.digest, 'changed payload digest');
    await b.command('commit',
        args: {'operationId': changed['operationId']},
        expectedError: 'constraint');
    await b.command('resolve',
        args: {
          'operationId': initial.request['operationId'],
          'payloadDigest': (await prepare(b, changed)),
        },
        expectedError: 'constraint');
    _check(jsonEncode(await read(b, id)) == jsonEncode(finalSnapshot),
        'changed-payload reuse does not mutate data');
    receipt(
        await a.command('resolve', args: {
          'operationId': initial.request['operationId'],
          'payloadDigest': initial.digest,
        }),
        initial);
    await a.command('close');
    await b.command('close');
    await a.command('deleteDatabase', args: {'database': database});
    return {
      'pageTargetIds': targets,
      'independentContextIds': contexts,
      'durableOperationsResolvedAndRetried': operations.length,
      'operations': [
        for (final operation in operations)
          {
            'request': operation.request,
            'precomputedDigest': operation.digest,
            'originalAndReplayedResult': operation.result,
          },
      ],
      'checks': [
        'same-revision race',
        'unique-value race and consistent records',
        'cross-tab delete/recreate ABA',
        'durable rejection after unique release',
        'destroy/reopen both pages',
        'resolve and retry every original operation',
        'no duplicate mutation or revision',
        'changed-payload reuse rejected'
      ],
    };
  }
}
