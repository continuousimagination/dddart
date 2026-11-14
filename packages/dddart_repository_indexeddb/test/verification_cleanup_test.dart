@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../tool/verification_cleanup.dart';

void main() {
  group('temporary browser profile deletion', () {
    late Directory temporary;
    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('dddart_cleanup_test_');
      await Directory('${temporary.path}/profile').create();
      await File('${temporary.path}/profile/Preferences').writeAsString('{}');
    });
    tearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });

    test('removes a populated real profile on the first attempt', () async {
      final directory = _FailingDirectory(temporary, failures: 0);
      await deleteTemporaryDirectory(directory);
      expect(directory.attempts, 1);
      expect(await temporary.exists(), isFalse);
    });

    test('retries transient filesystem failures before removing the profile',
        () async {
      final directory = _FailingDirectory(temporary, failures: 2);
      await deleteTemporaryDirectory(directory, retryDelay: Duration.zero);
      expect(directory.attempts, 3);
      expect(await temporary.exists(), isFalse);
    });

    test('a directory already removed is successful cleanup', () async {
      await temporary.delete(recursive: true);
      await deleteTemporaryDirectory(temporary);
      expect(await temporary.exists(), isFalse);
    });

    test('persistent failure is bounded and retains the final error and stack',
        () async {
      final directory = _FailingDirectory(temporary, failures: 10);
      try {
        await deleteTemporaryDirectory(directory, retryDelay: Duration.zero);
        fail('persistent deletion failure must be thrown');
      } catch (error, stack) {
        expect(error, same(directory.error));
        expect(stack.toString(), directory.stack.toString());
      }
      expect(directory.attempts, 5);
      expect(await temporary.exists(), isTrue);
    });

    test('non-filesystem errors are not retried', () async {
      final error = StateError('unexpected delete error');
      final directory =
          _FailingDirectory(temporary, failures: 10, error: error);
      await expectLater(
        deleteTemporaryDirectory(directory, retryDelay: Duration.zero),
        throwsA(same(error)),
      );
      expect(directory.attempts, 1);
    });
  });

  group('verification teardown', () {
    test('attempts every successful step without diagnostics', () async {
      final visited = <int>[];
      final messages = <String>[];
      await cleanupVerification([
        () async => visited.add(1),
        () async => visited.add(2),
      ], verificationFailed: false, report: messages.add);
      expect(visited, [1, 2]);
      expect(messages, isEmpty);
    });

    test(
        'fails a successful verification, reports all errors, runs later steps',
        () async {
      final first = StateError('socket cleanup');
      final second = const FileSystemException('profile still busy');
      final originalStack = StackTrace.fromString('original cleanup stack');
      final messages = <String>[];
      var lastStepRan = false;
      try {
        await cleanupVerification([
          () async => Error.throwWithStackTrace(first, originalStack),
          () async => throw second,
          () async {
            lastStepRan = true;
          },
        ], verificationFailed: false, report: messages.add);
        fail('cleanup failure must fail an otherwise successful run');
      } catch (error, stack) {
        expect(error, same(first));
        expect(stack.toString(), originalStack.toString());
      }
      expect(lastStepRan, isTrue);
      expect(messages, hasLength(2));
      expect(messages[0], contains('socket cleanup'));
      expect(messages[0], contains('original cleanup stack'));
      expect(messages[1], contains('profile still busy'));
    });

    for (final cleanupFails in [false, true]) {
      test(
          'preserves verification error and stack (cleanup fails: $cleanupFails)',
          () async {
        final original = StateError('original verification failure');
        final originalStack =
            StackTrace.fromString('original verification stack');
        final messages = <String>[];
        var lastStepRan = false;
        Future<void> run() async {
          var verificationFailed = false;
          try {
            Error.throwWithStackTrace(original, originalStack);
          } catch (_) {
            verificationFailed = true;
            rethrow;
          } finally {
            await cleanupVerification([
              () async {
                if (cleanupFails)
                  throw const FileSystemException('profile busy');
              },
              () async {
                lastStepRan = true;
              },
            ], verificationFailed: verificationFailed, report: messages.add);
          }
        }

        try {
          await run();
          fail('verification failure must still be thrown');
        } catch (error, stack) {
          expect(error, same(original));
          expect(stack.toString(), originalStack.toString());
        }
        expect(lastStepRan, isTrue);
        expect(messages, hasLength(cleanupFails ? 1 : 0));
        if (cleanupFails) expect(messages.single, contains('profile busy'));
      });
    }
  });
}

/// Injects late-profile-write failures while retaining real filesystem deletion.
class _FailingDirectory implements Directory {
  _FailingDirectory(this.delegate, {required this.failures, Object? error})
      : error = error ??
            FileSystemException(
              'Directory not empty',
              delegate.path,
              const OSError('Directory not empty', 39),
            );

  final Directory delegate;
  final int failures;
  final Object error;
  final StackTrace stack = StackTrace.fromString('original deletion stack');
  int attempts = 0;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    attempts++;
    if (attempts <= failures) Error.throwWithStackTrace(error, stack);
    return delegate.delete(recursive: recursive);
  }

  @override
  Future<bool> exists() => delegate.exists();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
