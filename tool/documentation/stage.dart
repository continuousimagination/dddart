import 'dart:io';

import '../validation/validation_core.dart';

/// Stage the same Pub-selected archive contents as the package consumer gate.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError('Expected temporary destination and package names');
  }
  final root = File.fromUri(Platform.script).parent.parent.parent.path;
  final inventory = loadInventory(root);
  for (final name in args.skip(1)) {
    final policy = inventory.packages[name];
    if (policy == null) throw ArgumentError('Unknown public package: $name');
    await stagePublishedPackage(
      sourceDirectory: '$root/${policy.path}',
      destinationDirectory: '${args.first}/packages/$name',
      archivePath: '${args.first}/archives/$name.tar.gz',
    );
    stdout.writeln('Staged Pub-selected archive: $name');
  }
}
