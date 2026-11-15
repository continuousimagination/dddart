@TestOn('browser')
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_iphone_probe/probe.dart';
import 'package:idb_shim/idb_client_native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'native harness survives serialized state, retries and injected failures',
    () async {
      final state = <String, dynamic>{'runId': UuidValue.generate().uuid};
      String? checkpoint;
      final checks = <String>[];
      final probe = Probe(idbFactoryNative, state, () {
        checkpoint = jsonEncode(state);
      }, (_, text) => checks.add(text));
      try {
        await probe.baseline();
        await probe.dispatchUnobserved();
        final restored = jsonDecode(checkpoint!) as Map<String, dynamic>;
        final resumed = Probe(
          idbFactoryNative,
          restored,
          () {},
          (_, text) => checks.add(text),
        );
        await resumed.reconcile();
        await resumed.failures();
        await resumed.verify();
        expect(restored['baselineComplete'], isTrue);
        expect(restored['recoveryComplete'], isTrue);
        expect(restored['failuresComplete'], isTrue);
        expect(checks.length, greaterThan(60));
        // Deliberate data loss must fail verification; never silently reseed it.
        await idbFactoryNative.deleteDatabase('${probe.prefix}-main');
        await expectLater(
          resumed.verify(),
          throwsA(isA<RepositoryException>()),
        );
      } finally {
        for (final suffix in ['main', 'recovery', 'schema', 'fault']) {
          await idbFactoryNative.deleteDatabase('${probe.prefix}-$suffix');
        }
      }
    },
  );
}
