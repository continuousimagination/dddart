import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:dddart/dddart.dart';
import 'package:dddart_iphone_probe/probe.dart';
import 'package:idb_shim/idb_client_native.dart';

const harnessCommit = String.fromEnvironment(
  'HARNESS_COMMIT',
  defaultValue: 'development',
);
const sourceDirty = bool.fromEnvironment('SOURCE_DIRTY', defaultValue: true);
final documentId = UuidValue.generate().uuid;
Map<String, dynamic>? state;
bool busy = false;
String? startupError;
Element element(String id) => querySelector('#$id')!;
InputElement input(String id) => element(id) as InputElement;
String now() => DateTime.now().toUtc().toIso8601String();
void persist() {
  if (state != null)
    window.localStorage['dddart-77-report-${state!['runId']}'] = jsonEncode(
      state,
    );
}

void log(String status, String message) {
  (state!['events'] as List).add({
    'at': now(),
    'documentId': documentId,
    'status': status,
    'message': message,
  });
  persist();
  render();
}

Probe get probe => Probe(idbFactoryNative, state!, persist, log);

void render() {
  final s = state;
  element('provenance').text =
      'Adapter/core: $testedSha\nHarness: $harnessCommit${sourceDirty ? ' (working tree)' : ''}';
  element('run').text = s == null
      ? (startupError ?? 'No run started.')
      : 'Run ${s['runId']} • ${s['mode']}';
  element('run-url').text = window.location.href;
  final events = (s?['events'] as List?) ?? [];
  element('log').text = events
      .map(
        (e) =>
            '${e['at']}  ${e['status'].toString().toUpperCase()}  ${e['message']}',
      )
      .join('\n');
  final failed =
      startupError != null || events.any((e) => e['status'] == 'fail');
  final lifecycle = (s?['lifecycle'] as List?) ?? [];
  final complete =
      s?['baselineComplete'] == true &&
      s?['recoveryComplete'] == true &&
      s?['failuresComplete'] == true &&
      ['reload', 'background', 'reopen'].every(
        (kind) =>
            lifecycle.any((e) => e['kind'] == kind && e['status'] == 'pass'),
      );
  element('status').text = busy
      ? 'Running…'
      : failed
      ? 'FAIL — preserve this run and export or report the error.'
      : complete
      ? 'Checklist complete for this mode — export for review.'
      : 'Checklist incomplete';
  element('status').classes.toggle('failed', failed);
  element('status').classes.toggle('passed', complete && !failed);
  void enable(String id, bool value) =>
      (element(id) as ButtonElement).disabled = busy || !value;
  enable('baseline', s == null && startupError == null);
  enable(
    'unknown',
    s?['baselineComplete'] == true && s?['pendingOperation'] == null && !failed,
  );
  enable(
    'reconcile',
    s?['pendingOperation'] != null && s?['recoveryComplete'] != true && !failed,
  );
  enable(
    'failures',
    s?['recoveryComplete'] == true && s?['failuresStarted'] != true && !failed,
  );
  final ready =
      s?['failuresComplete'] == true &&
      s?['pendingLifecycle'] == null &&
      !failed;
  for (final id in ['reload', 'background', 'reopen']) {
    enable(id, ready);
  }
  enable('verify', s?['pendingLifecycle'] != null && !failed);
  enable('export', s != null);
  enable('report', s != null);
  element('pending').text = s?['pendingLifecycle'] == null
      ? ''
      : 'Pending: ${(s!['pendingLifecycle'] as Map)['kind']}. Complete the action, tick the confirmation, then Verify.';
}

Future<void> action(String name, Future<void> Function() body) async {
  if (busy) return;
  busy = true;
  render();
  try {
    await body().timeout(const Duration(seconds: 45));
    if (state != null) log('pass', '$name complete');
  } catch (e, stack) {
    if (state != null) {
      (state!['events'] as List).add({
        'at': now(),
        'documentId': documentId,
        'status': 'fail',
        'message': '$name: $e',
        'stack': stack.toString(),
      });
      try {
        persist();
      } catch (_) {}
    } else {
      startupError = '$name: $e';
    }
  } finally {
    busy = false;
    render();
  }
}

Future<void> start() async {
  if (input('model').value!.trim().isEmpty ||
      input('ios').value!.trim().isEmpty) {
    window.alert('Enter device model and OS version first.');
    return;
  }
  final runId = UuidValue.generate().uuid;
  state = {
    'reportVersion': 1,
    'runId': runId,
    'startedAt': now(),
    'testedSha': testedSha,
    'harnessCommit': harnessCommit,
    'sourceDirty': sourceDirty,
    'model': input('model').value!.trim(),
    'osVersion': input('ios').value!.trim(),
    'userAgent': window.navigator.userAgent,
    'platform': window.navigator.platform,
    'mode': window.matchMedia('(display-mode: standalone)').matches
        ? 'standalone-home-screen'
        : 'browser-tab',
    'origin': window.location.origin,
    'https': window.location.protocol == 'https:',
    'nativeIndexedDb': true,
    'events': <dynamic>[],
    'lifecycle': <dynamic>[],
    'limitations': [
      'Operator confirms physical device and lifecycle actions; browser metadata alone cannot prove them.',
      'Lost-result recovery deliberately discards completion; no forced OS kill during a transaction is claimed.',
      'Upgrade abort, unavailable storage and receipt-write failure are injected over native IndexedDB.',
      'Actual quota exhaustion, storage eviction, long-term retention, offline loading and other browser/modes are untested.',
      'WebKit is recorded through the user agent plus operator-supplied iOS version; exact engine build may not be exposed.',
      'Independent review pending; a completed checklist is not a platform support claim.',
    ],
  };
  persist();
  window.location.hash = runId;
  log('info', 'Operator details recorded; native IndexedDB only.');
  await probe.baseline();
}

Future<void> arm(String kind) async {
  input('confirm').checked = false;
  state!['pendingLifecycle'] = {
    'kind': kind,
    'armedAt': now(),
    'documentId': documentId,
  };
  log('info', 'Armed $kind; run URL must remain unchanged.');
  if (kind == 'reload') window.location.reload();
}

Future<void> verifyLifecycle() async {
  if (input('confirm').checked != true) {
    window.alert('Confirm the physical action before verification.');
    return;
  }
  final pending = Map<String, dynamic>.from(state!['pendingLifecycle'] as Map);
  final kind = pending['kind'];
  final events = state!['events'] as List;
  if (kind == 'reload' && pending['documentId'] == documentId)
    throw StateError('No new page load observed.');
  if (kind == 'background' &&
      !events.any(
        (e) =>
            e['at'].toString().compareTo(pending['armedAt'] as String) >= 0 &&
            e['message'] == 'visibility:hidden',
      )) {
    throw StateError('No background visibility event recorded since arming.');
  }
  try {
    await probe.verify();
    (state!['lifecycle'] as List).add({
      ...pending,
      'verifiedAt': now(),
      'status': 'pass',
      'operatorConfirmed': true,
      'newDocument': pending['documentId'] != documentId,
    });
    state!.remove('pendingLifecycle');
    persist();
  } catch (e) {
    (state!['lifecycle'] as List).add({
      ...pending,
      'verifiedAt': now(),
      'status': 'fail',
      'error': '$e',
    });
    persist();
    rethrow;
  }
}

String reportText() {
  state!['operatorNotes'] = (element('notes') as TextAreaElement).value;
  state!['exportedAt'] = now();
  state!['summary'] = {
    'hasFailures': (state!['events'] as List).any((e) => e['status'] == 'fail'),
    'baselineComplete': state!['baselineComplete'] == true,
    'recoveryComplete': state!['recoveryComplete'] == true,
    'failureSuiteComplete': state!['failuresComplete'] == true,
    'lifecyclePassed': (state!['lifecycle'] as List)
        .where((e) => e['status'] == 'pass')
        .map((e) => e['kind'])
        .toList(),
    'independentReview': 'pending',
  };
  try {
    persist();
  } catch (_) {}
  return const JsonEncoder.withIndent('  ').convert(state);
}

void main() {
  final runId = window.location.hash.replaceFirst('#', '');
  if (runId.isNotEmpty) {
    try {
      final saved = window.localStorage['dddart-77-report-$runId'];
      if (saved == null)
        throw StateError(
          'Run manifest missing. Do not restart: report this URL and a screenshot as possible storage loss.',
        );
      state = jsonDecode(saved) as Map<String, dynamic>;
      if (state!['testedSha'] != testedSha ||
          state!['harnessCommit'] != harnessCommit)
        throw StateError(
          'Harness changed during run. Export and use the original build.',
        );
      input('model').value = state!['model'] as String;
      input('ios').value = state!['osVersion'] as String;
      (element('notes') as TextAreaElement).value =
          state!['operatorNotes'] as String? ?? '';
      log('info', 'Page loaded; previous run restored without reseeding.');
    } catch (e) {
      startupError = '$e';
      if (state != null)
        (state!['events'] as List).add({
          'at': now(),
          'documentId': documentId,
          'status': 'fail',
          'message': startupError,
        });
    }
  }
  void bind(String id, String name, Future<void> Function() body) =>
      element(id).onClick.listen((_) => action(name, body));
  bind('baseline', 'Baseline', start);
  bind('unknown', 'Unobserved completion', () async {
    await probe.dispatchUnobserved();
    window.location.reload();
  });
  bind(
    'reconcile',
    'Reconciliation and identical retry',
    () => probe.reconcile(),
  );
  bind('failures', 'Schema and injected failures', () => probe.failures());
  for (final kind in ['reload', 'background', 'reopen']) {
    bind(kind, 'Arm $kind', () => arm(kind));
  }
  bind('verify', 'Lifecycle verification', verifyLifecycle);
  element('export').onClick.listen((_) {
    final url = Url.createObjectUrlFromBlob(
      Blob([reportText()], 'application/json'),
    );
    AnchorElement(href: url)
      ..download = 'dddart-77-${state!['runId']}.json'
      ..click();
    Timer(const Duration(seconds: 30), () => Url.revokeObjectUrl(url));
  });
  element('report').onClick.listen((_) {
    final output = element('report-text') as TextAreaElement;
    output.value = reportText();
    output.hidden = false;
    output.select();
  });
  document.onVisibilityChange.listen((_) {
    if (state != null) {
      try {
        log('info', 'visibility:${document.visibilityState}');
      } catch (_) {}
    }
  });
  for (final event in ['pagehide', 'pageshow']) {
    window.addEventListener(event, (_) {
      if (state != null) {
        try {
          log('info', event);
        } catch (_) {}
      }
    });
  }
  render();
}
