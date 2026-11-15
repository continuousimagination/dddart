import 'dart:async';
import 'dart:io';

/// Removes a test-owned profile, allowing late browser child-process writes.
///
/// Attempts deletion at most five times, with 1.5 seconds of backoff. A missing
/// directory is already clean; a persistent failure retains its error/stack.
Future<void> deleteTemporaryDirectory(
  Directory directory, {
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (!await directory.exists()) return;
      if (attempt == 4) rethrow;
      await Future<void>.delayed(retryDelay * (1 << attempt));
    }
  }
}

/// Attempts every teardown step, without masking a verification failure.
///
/// Every cleanup failure is reported. If verification succeeded, the first
/// cleanup failure is rethrown with its original stack so the run fails too.
Future<void> cleanupVerification(
  List<Future<void> Function()> steps, {
  required bool verificationFailed,
  void Function(String)? report,
}) async {
  Object? firstError;
  StackTrace? firstStack;
  for (final step in steps) {
    try {
      await step();
    } catch (error, stack) {
      (report ?? stderr.writeln)('Verification cleanup failed: $error\n$stack');
      firstError ??= error;
      firstStack ??= stack;
    }
  }
  if (!verificationFailed && firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}
