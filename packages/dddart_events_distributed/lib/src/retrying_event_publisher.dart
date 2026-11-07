import 'dart:async';
import 'dart:math';

import 'package:dddart/dddart.dart';
import 'package:http/http.dart' as http;

/// A transport rejection with an explicit transient/permanent classification.
class EventPublicationException implements Exception {
  /// Describes a rejection without including credentials or event payloads.
  const EventPublicationException(this.message, {this.retryable = false});

  /// Safe diagnostic text supplied by the transport.
  final String message;

  /// Whether retrying the same occurrence may succeed.
  final bool retryable;

  @override
  String toString() => 'EventPublicationException: $message';
}

/// Bounded retry policy shared by distributed publishers.
class EventRetryPolicy {
  /// Creates a policy; [maxAttempts] includes the first attempt.
  EventRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 1),
    this.attemptTimeout = const Duration(seconds: 2),
    this.maxElapsed = const Duration(seconds: 6),
    this.jitter = 0.2,
  }) {
    if (maxAttempts < 1 ||
        initialDelay.isNegative ||
        maxDelay < initialDelay ||
        attemptTimeout <= Duration.zero ||
        maxElapsed <= Duration.zero ||
        !jitter.isFinite ||
        jitter < 0 ||
        jitter > 1) {
      throw ArgumentError('Invalid bounded event retry policy');
    }
  }

  /// Total number of attempts, including the initial send.
  final int maxAttempts;

  /// Base delay before the second attempt.
  final Duration initialDelay;

  /// Maximum backoff delay, including jitter.
  final Duration maxDelay;

  /// Maximum time spent waiting for one transport attempt.
  final Duration attemptTimeout;

  /// Total waiting budget for one publication, including backoff.
  final Duration maxElapsed;

  /// Random fractional variation applied to exponential backoff.
  final double jitter;
}

/// Retries transient publication failures and logs final failure in one place.
///
/// The send callback must complete only after durable acceptance. It preserves the
/// supplied event UUID and reject conflicting retries. A timeout bounds waiting,
/// not remote execution: transports must cancel their own requests when possible,
/// and late/uncertain acceptance must remain safe to retry with the same UUID.
/// No unbounded background worker or consumer-processing acknowledgment is used.
class RetryingEventPublisher implements EventPublisher {
  /// Configures a transport callback and shared retry/logging policy.
  RetryingEventPublisher({
    required Future<void> Function(DomainEvent<Identity>) send,
    EventRetryPolicy? policy,
    Logger? logger,
    Future<void> Function(Duration)? delay,
    Random? random,
  })  : _send = send,
        policy = policy ?? EventRetryPolicy(),
        logger = logger ?? Logger('dddart.events.publisher'),
        _delay = delay ?? Future<void>.delayed,
        _random = random ?? Random();

  final Future<void> Function(DomainEvent<Identity>) _send;
  final Future<void> Function(Duration) _delay;
  final Random _random;

  /// Retry limits for this publisher.
  final EventRetryPolicy policy;

  /// Named logger used for retry and final-failure diagnostics.
  final Logger logger;

  @override
  Future<bool> publish(DomainEvent<Identity> event) async {
    final watch = Stopwatch()..start();
    var backoff = policy.initialDelay;
    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      final remaining = policy.maxElapsed - watch.elapsed;
      if (remaining <= Duration.zero) {
        _failed(
          event,
          attempt - 1,
          TimeoutException('Publication budget expired'),
        );
        return false;
      }
      final finalTimeout = remaining <= policy.attemptTimeout;
      final timeout = finalTimeout ? remaining : policy.attemptTimeout;
      try {
        await _send(event).timeout(timeout);
        return true;
      } catch (error, stackTrace) {
        // A timeout clipped to the total budget is terminal. Timer granularity
        // may leave a few microseconds on Stopwatch; retrying that sliver can
        // otherwise create a burst of attempts whose timers round down to zero.
        if (!_retryable(error) ||
            attempt == policy.maxAttempts ||
            (error is TimeoutException && finalTimeout)) {
          _failed(event, attempt, error, stackTrace);
          return false;
        }
        final micros = (backoff.inMicroseconds *
                (1 + policy.jitter * (2 * _random.nextDouble() - 1)))
            .round();
        final delay = Duration(
          microseconds: min(micros, policy.maxDelay.inMicroseconds),
        );
        final budget = policy.maxElapsed - watch.elapsed;
        if (delay >= budget) {
          _failed(event, attempt, error, stackTrace);
          return false;
        }
        logger.warning(
          'Retrying event ${event.eventId} after attempt $attempt',
          error,
          stackTrace,
        );
        try {
          await _delay(delay).timeout(budget);
        } catch (error, stackTrace) {
          _failed(event, attempt, error, stackTrace);
          return false;
        }
        backoff = Duration(
          microseconds: min(
            backoff.inMicroseconds * 2,
            policy.maxDelay.inMicroseconds,
          ),
        );
      }
    }
    return false;
  }

  bool _retryable(Object error) =>
      error is TimeoutException ||
      error is http.ClientException ||
      (error is EventPublicationException && error.retryable) ||
      (error is RepositoryException &&
          (error.type == RepositoryExceptionType.connection ||
              error.type == RepositoryExceptionType.timeout));

  void _failed(
    DomainEvent<Identity> event,
    int attempts,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    logger.severe(
      'Event publication failed: ${event.eventId} '
      '(${event.runtimeType}), attempts=$attempts',
      error,
      stackTrace,
    );
  }
}
