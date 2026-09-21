/// Lambda Runtime API lifecycle without retrying an uncertain response delivery.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dddart_rest/src/lambda/http_api_v2_adapter.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// Runs a Shelf application using the Lambda custom-runtime protocol.
///
/// The injected HTTP client is borrowed and never closed here. A terminal
/// Runtime API/response delivery failure throws; the application entry point
/// must exit instead of restarting this runtime or replaying a response.
class LambdaRuntime {
  /// Creates a runtime for an already initialized Shelf handler.
  LambdaRuntime({
    required Handler handler,
    required this.client,
    required this.endpoint,
    this.deliveryTimeout = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _adapter = HttpApiV2Adapter(handler),
       _clock = clock ?? DateTime.now {
    _validateEndpoint(endpoint);
    _validateDeliveryTimeout(deliveryTimeout);
  }

  /// Borrowed Runtime API transport.
  final http.Client client;

  /// Runtime API origin, for example http://127.0.0.1:9001.
  final Uri endpoint;

  /// Bound for a response/error POST; never applies to the next long poll.
  final Duration deliveryTimeout;
  final HttpApiV2Adapter _adapter;
  final DateTime Function() _clock;
  bool _terminated = false;
  bool _busy = false;

  /// Initializes the handler, reporting a safe init/error on startup failure.
  static Future<LambdaRuntime> initialize({
    required FutureOr<Handler> Function() initializeHandler,
    required http.Client client,
    required Uri endpoint,
    Duration deliveryTimeout = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) async {
    _validateEndpoint(endpoint);
    _validateDeliveryTimeout(deliveryTimeout);
    late Handler handler;
    try {
      handler = await initializeHandler();
    } catch (_) {
      await _post(
        client,
        endpoint,
        ['init', 'error'],
        _error('InitializationFailure', 'Runtime initialization failed'),
        deliveryTimeout: deliveryTimeout,
      );
      throw StateError('Lambda runtime initialization failed');
    }
    return LambdaRuntime(
      handler: handler,
      client: client,
      endpoint: endpoint,
      deliveryTimeout: deliveryTimeout,
      clock: clock,
    );
  }

  /// Processes invocations until a terminal protocol or delivery failure throws.
  Future<void> run() async {
    while (true) {
      await runOnce();
    }
  }

  /// Processes exactly one invocation, useful for deterministic protocol tests.
  Future<void> runOnce() async {
    if (_terminated) throw StateError('Lambda runtime is terminated');
    if (_busy) throw StateError('Lambda invocation is already in progress');
    _busy = true;
    try {
      await _invoke();
    } catch (_) {
      _terminated = true;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> _invoke() async {
    late http.Response next;
    try {
      // AWS explicitly requires no timeout on the long-polling next request.
      next = await client.get(
        endpoint.replace(
          pathSegments: ['2018-06-01', 'runtime', 'invocation', 'next'],
        ),
      );
    } catch (_) {
      throw StateError('Runtime API next request failed');
    }
    if (next.statusCode != 200) {
      throw StateError('Runtime API next request was rejected');
    }
    final requestId = next.headers['lambda-runtime-aws-request-id'];
    final deadline = int.tryParse(
      next.headers['lambda-runtime-deadline-ms'] ?? '',
    );
    final invocationId = next.headers['lambda-runtime-invocation-id'];
    if (requestId == null ||
        requestId.isEmpty ||
        deadline == null ||
        requestId.contains('\r') ||
        requestId.contains('\n') ||
        (invocationId?.contains('\r') ?? false) ||
        (invocationId?.contains('\n') ?? false)) {
      throw StateError('Invalid Runtime API invocation metadata');
    }
    late LambdaInvocationContext context;
    try {
      context = LambdaInvocationContext(
        requestId: requestId,
        deadline: DateTime.fromMillisecondsSinceEpoch(deadline, isUtc: true),
        invocationId: invocationId,
      );
    } catch (_) {
      throw StateError('Invalid Runtime API deadline');
    }
    Map<String, Object?> payload;
    var disposition = 'response';
    var deadlineExpired = false;
    try {
      final remaining = context.deadline.difference(_clock().toUtc());
      if (remaining <= Duration.zero) throw const _InvocationDeadlineExceeded();
      final event = jsonDecode(utf8.decode(next.bodyBytes));
      if (event is! Map<String, Object?>) {
        throw const FormatException('Invalid invocation envelope');
      }
      payload = await _adapter
          .handle(event, context: context)
          .timeout(
            remaining,
            onTimeout: () => throw const _InvocationDeadlineExceeded(),
          );
    } on _InvocationDeadlineExceeded {
      deadlineExpired = true;
      _terminated = true;
      disposition = 'error';
      payload = _error('InvocationTimeout', 'Invocation timed out');
    } catch (_) {
      disposition = 'error';
      payload = _error('InvocationFailure', 'Invocation processing failed');
    }
    // A posting failure is never recast as a handler failure or posted twice.
    await _post(
      client,
      endpoint,
      ['invocation', requestId, disposition],
      payload,
      deliveryTimeout: deliveryTimeout,
      invocationId: invocationId,
    );
    if (deadlineExpired) {
      throw StateError('Invocation deadline exceeded; runtime terminated');
    }
  }

  static Map<String, Object?> _error(String type, String message) => {
    'errorType': type,
    'errorMessage': message,
    'stackTrace': <String>[],
  };

  static Future<void> _post(
    http.Client client,
    Uri endpoint,
    List<String> path,
    Map<String, Object?> payload, {
    required Duration deliveryTimeout,
    String? invocationId,
  }) async {
    late http.Response response;
    try {
      response = await client
          .post(
            endpoint.replace(pathSegments: ['2018-06-01', 'runtime', ...path]),
            headers: {
              'content-type': 'application/json',
              if (invocationId != null)
                'lambda-runtime-invocation-id': invocationId,
            },
            body: jsonEncode(payload),
          )
          .timeout(deliveryTimeout);
    } catch (_) {
      throw StateError('Runtime API delivery failed');
    }
    if (response.statusCode != 202) {
      throw StateError('Runtime API delivery was rejected');
    }
  }

  static void _validateEndpoint(Uri endpoint) {
    if (!const {'http', 'https'}.contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.path.isNotEmpty && endpoint.path != '/')) {
      throw ArgumentError('Runtime API endpoint must be an HTTP origin');
    }
  }

  static void _validateDeliveryTimeout(Duration value) {
    if (value <= Duration.zero) {
      throw ArgumentError('Runtime API delivery timeout must be positive');
    }
  }
}

class _InvocationDeadlineExceeded implements Exception {
  const _InvocationDeadlineExceeded();
}
