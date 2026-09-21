/// Lossless, validated HTTP API v2 to Shelf adaptation.
library;

import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Lambda invocation metadata, distinct from API Gateway's request identifier.
class LambdaInvocationContext {
  /// Creates invocation metadata supplied by the trusted Runtime API.
  LambdaInvocationContext({
    required this.requestId,
    required DateTime deadline,
    this.invocationId,
  }) : deadline = deadline.toUtc();

  /// Shelf context key containing this typed object.
  static const contextKey = 'dddart.lambda.invocation';

  /// Identifier used in the Runtime API response/error URL.
  final String requestId;

  /// Absolute invocation deadline.
  final DateTime deadline;

  /// Optional invocation-attempt identifier echoed on response/error requests.
  final String? invocationId;
}

/// Validated fields used from an API Gateway HTTP API payload version 2.0.
class HttpApiV2Request {
  /// Validates a v2 envelope before constructing a Shelf request.
  factory HttpApiV2Request.fromJson(Map<String, Object?> json) {
    if (json['version'] != '2.0') {
      throw const FormatException('Unsupported payload version');
    }
    final context = json['requestContext'];
    if (context is! Map<String, Object?> ||
        context['http'] is! Map<String, Object?>) {
      throw const FormatException('Missing HTTP context');
    }
    final http = context['http']! as Map<String, Object?>;
    final method = _text(http['method']);
    if (!RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$").hasMatch(method)) {
      throw const FormatException('Invalid method');
    }
    final path = _text(json['rawPath']);
    final query = _text(json['rawQueryString'] ?? '');
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('?') ||
        path.contains('#') ||
        query.contains('#')) {
      throw const FormatException('Invalid request URI');
    }
    final values = json['headers'];
    if (values is! Map<String, Object?>) {
      throw const FormatException('Invalid headers');
    }
    final headers = <String, String>{};
    for (final entry in values.entries) {
      final name = _text(entry.key).toLowerCase();
      final value = _text(entry.value);
      if (!RegExp(r"^[!#$%&'*+\-.^_`|~0-9a-z]+$").hasMatch(name) ||
          value.contains('\r') ||
          value.contains('\n') ||
          headers.containsKey(name)) {
        throw const FormatException('Invalid header');
      }
      headers[name] = value;
    }
    final cookies = json['cookies'];
    if (cookies != null) {
      if (cookies is! List<Object?>) {
        throw const FormatException('Invalid cookies');
      }
      final entries = [
        if (headers.containsKey('cookie')) headers['cookie']!,
        ...cookies.map(_text),
      ];
      if (entries.any(
        (value) => value.contains('\r') || value.contains('\n'),
      )) {
        throw const FormatException('Invalid cookies');
      }
      if (entries.isNotEmpty) headers['cookie'] = entries.join('; ');
    }
    final encoded = json['isBase64Encoded'] ?? false;
    if (encoded is! bool) throw const FormatException('Invalid body encoding');
    final text = json['body'] == null ? '' : _text(json['body']);
    final bytes = encoded ? base64Decode(text) : utf8.encode(text);
    String? optional(String key) =>
        context[key] == null ? null : _text(context[key]);
    return HttpApiV2Request._(
      method: method,
      rawPath: path,
      rawQueryString: query,
      headers: Map.unmodifiable(headers),
      body: List.unmodifiable(bytes),
      apiId: optional('apiId'),
      stage: optional('stage'),
      requestId: optional('requestId'),
      domainName: optional('domainName'),
    );
  }
  HttpApiV2Request._({
    required this.method,
    required this.rawPath,
    required this.rawQueryString,
    required this.headers,
    required this.body,
    required this.apiId,
    required this.stage,
    required this.requestId,
    required this.domainName,
  });

  /// Shelf context key containing the original typed HTTP API metadata.
  static const contextKey = 'dddart.httpApiV2.request';

  /// HTTP method.
  final String method;

  /// Original encoded path, without a custom-domain API mapping prefix.
  final String rawPath;

  /// Original query text, preserving repeated parameters.
  final String rawQueryString;

  /// Validated headers; repeated gateway headers remain comma-combined.
  final Map<String, String> headers;

  /// Exact decoded request bytes.
  final List<int> body;

  /// Provider domain name used as request authority when supplied.
  final String? domainName;

  /// API Gateway API identifier, when supplied.
  final String? apiId;

  /// API Gateway stage, when supplied.
  final String? stage;

  /// API Gateway's request identifier, not Lambda's Runtime API identifier.
  final String? requestId;

  static String _text(Object? value) {
    if (value is! String) throw const FormatException('Expected text');
    // utf8.encode replaces lone UTF-16 surrogates; reject them before any loss.
    final units = value.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          throw const FormatException('Malformed Unicode');
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw const FormatException('Malformed Unicode');
      }
    }
    return value;
  }
}

/// Adapts a validated v2 invocation to a socket-independent Shelf handler.
///
/// Returning null continues all normal validation and authentication. Returning
/// a response rejects; only400–599 are permitted. The callback is synchronous,
/// borrows nested event values read-only. Pure validators may be wrapped with
/// bounded local rejection telemetry, but no network, repository,
/// authentication or other protected I/O may run in the callback.
typedef HttpApiV2Preflight =
    Response? Function(
      Map<String, Object?> event,
      LambdaInvocationContext context,
    );

/// Adapts a validated v2 invocation to a socket-independent Shelf handler.
class HttpApiV2Adapter {
  /// Uses the same handler that can be hosted by a normal Shelf server.
  const HttpApiV2Adapter(this.handler, {this.preflight});

  /// Application routing and middleware.
  final Handler handler;

  /// Optional rejection-only policy before any request body decoding.
  final HttpApiV2Preflight? preflight;

  /// Returns a v2 response; handler failures propagate to the Runtime API loop.
  Future<Map<String, Object?>> handle(
    Map<String, Object?> event, {
    required LambdaInvocationContext context,
  }) async {
    Response? rejection;
    try {
      // Only the top-level view is immutable; nested data remains borrowed.
      rejection = preflight?.call(Map.unmodifiable(event), context);
    } catch (_) {
      throw StateError('HTTP ingress preflight failed');
    }
    if (rejection != null) {
      if (rejection.statusCode < 400 || rejection.statusCode > 599) {
        throw StateError('HTTP ingress preflight must reject');
      }
      return _encodeResponse(rejection);
    }
    late HttpApiV2Request input;
    late Uri uri;
    try {
      input = HttpApiV2Request.fromJson(event);
      // Parse the already-encoded path/query instead of encoding percent signs.
      final authority =
          input.domainName ?? input.headers['host'] ?? 'lambda.invalid';
      final origin = Uri.parse('https://$authority');
      if (origin.host.isEmpty ||
          origin.userInfo.isNotEmpty ||
          origin.path.isNotEmpty ||
          origin.hasQuery ||
          origin.hasFragment ||
          authority.contains(',')) {
        throw const FormatException('Invalid HTTP authority');
      }
      uri = Uri.parse(
        '${origin.origin}${input.rawPath}${input.rawQueryString.isEmpty ? '' : '?${input.rawQueryString}'}',
      );
    } on FormatException {
      return {
        'statusCode': 400,
        'headers': {'content-type': 'application/json'},
        'body': '{"error":"Invalid HTTP request"}',
        'isBase64Encoded': false,
      };
    }
    final request = Request(
      input.method,
      uri,
      headers: input.headers,
      body: input.body,
      context: {
        LambdaInvocationContext.contextKey: context,
        HttpApiV2Request.contextKey: input,
      },
    );
    return _encodeResponse(await handler(request));
  }

  static Future<Map<String, Object?>> _encodeResponse(Response response) async {
    final bytes = await response.read().expand((chunk) => chunk).toList();
    var encoded = false;
    late String body;
    try {
      body = utf8.decode(bytes);
    } on FormatException {
      body = base64Encode(bytes);
      encoded = true;
    }
    final headers = <String, String>{};
    final cookies = <String>[];
    for (final entry in response.headersAll.entries) {
      final name = entry.key.toLowerCase();
      if (name == 'set-cookie') {
        cookies.addAll(entry.value);
      } else if (!const {
        'content-length',
        'transfer-encoding',
        'connection',
      }.contains(name)) {
        headers[name] = entry.value.join(',');
      }
    }
    return {
      'statusCode': response.statusCode,
      'headers': headers,
      'body': body,
      'isBase64Encoded': encoded,
      if (cookies.isNotEmpty) 'cookies': cookies,
    };
  }
}
