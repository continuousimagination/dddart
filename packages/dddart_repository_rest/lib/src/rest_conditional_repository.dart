import 'dart:async';
import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_repository_rest/src/connection/rest_connection.dart';
import 'package:dddart_rest/dddart_rest_protocol.dart';
import 'package:http/http.dart' as http;

/// Portable explicit conditional CRUD against one canonical JSON resource.
///
/// Uses a trusted stable codec and connection/auth composition without write
/// retries or auth-refresh retries. Redirects are disabled on every request.
/// Browser-internal retransmission remains possible; atomic server conditions
/// fence mutation and every post-dispatch failure preserves logical uncertainty.
class RestConditionalRepository<T extends VersionedAggregateRoot>
    implements ConditionalRepository<T> {
  /// Creates the typed adapter without reading or caching a remote revision.
  RestConditionalRepository(
    this.connection, {
    required this.serializer,
    required String resourcePath,
  }) : resourcePath = resourcePath.startsWith('/')
           ? resourcePath
           : '/$resourcePath',
       _client = _NoRedirectClient(connection.client) {
    final base = Uri.parse(connection.baseUrl);
    if (!const {'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        connection.baseUrl.endsWith('/') ||
        this.resourcePath == '/' ||
        this.resourcePath.endsWith('/') ||
        this.resourcePath.contains('?') ||
        this.resourcePath.contains('#')) {
      throw ArgumentError('Invalid resource configuration.');
    }
  }

  /// Trusted HTTP/auth connection; its owner retains disposal responsibility.
  final RestConnection connection;

  /// Trusted stable canonical JSON codec, shared with the resource owner.
  final JsonSerializer<T> serializer;

  /// Resource prefix fixed by trusted adapter configuration.
  final String resourcePath;
  final http.Client _client;

  Uri _uri(UuidValue id) =>
      Uri.parse('${connection.baseUrl}$resourcePath/${id.uuid}');

  @override
  Future<T> getById(UuidValue id) async {
    try {
      final response = await _client.get(
        _uri(id),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) throw _status(response.statusCode);
      final wire = _responseJson(response);
      final value = _decode(wire, id);
      if (value.revision.value == 0 ||
          ConditionalHeaders.parseEtag(_header(response, 'etag')) !=
              value.revision) {
        throw const RepositoryCapabilityException();
      }
      return value;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<T> save(T proposed, {required WritePrecondition precondition}) async {
    final expected = switch (precondition) {
      AbsentWritePrecondition() => const Revision.zero(),
      RevisionWritePrecondition(:final revision) => revision,
    };
    if (proposed.revision != expected) {
      throw ArgumentError('Proposal revision must match its precondition.');
    }
    final next = expected.next();
    late final Map<String, dynamic> wire;
    try {
      wire = _wire(proposed);
      final reconstructed = _decode(
        jsonDecode(jsonEncode(wire)) as Map<String, dynamic>,
        proposed.id,
      );
      if (identical(reconstructed, proposed)) {
        throw const RepositoryCapabilityException();
      }
    } catch (_) {
      throw const RepositoryCapabilityException();
    }
    final body = jsonEncode(wire);
    final uri = _uri(proposed.id);
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...ConditionalHeaders.forWrite(precondition),
    };
    try {
      // Entry into put is possible dispatch, even if a later error has a code
      // normally used for rejection. A previous physical copy may have committed.
      final response = await _client.put(uri, headers: headers, body: body);
      if (response.statusCode != (expected.value == 0 ? 201 : 200)) {
        throw _status(response.statusCode);
      }
      if (_header(response, 'etag') != null ||
          _header(response, 'last-modified') != null) {
        throw const RepositoryCapabilityException();
      }
      final acceptedWire = _responseJson(response);
      final accepted = _decode(acceptedWire, proposed.id);
      if (identical(accepted, proposed) ||
          accepted.revision != next ||
          !_same({...wire, 'revision': next.value}, acceptedWire)) {
        throw const RepositoryCapabilityException();
      }
      return accepted;
    } catch (error) {
      throw WriteOutcomeUnknownException(observedFailure: _failure(error).type);
    }
  }

  @override
  Future<void> deleteById(
    UuidValue id, {
    required WritePrecondition precondition,
  }) async {
    if (precondition is! RevisionWritePrecondition) {
      throw ArgumentError('Retirement requires a positive expected revision.');
    }
    precondition.revision.next();
    final uri = _uri(id);
    final headers = ConditionalHeaders.forWrite(precondition);
    try {
      final response = await _client.delete(uri, headers: headers);
      if (response.statusCode != 204 || response.bodyBytes.isNotEmpty) {
        throw _status(response.statusCode);
      }
    } catch (error) {
      throw WriteOutcomeUnknownException(observedFailure: _failure(error).type);
    }
  }

  String? _header(http.Response response, String name) {
    final matches = response.headers.entries
        .where((entry) => entry.key.toLowerCase() == name)
        .toList();
    if (matches.length > 1) throw const RepositoryCapabilityException();
    return matches.isEmpty ? null : matches.single.value;
  }

  Map<String, dynamic> _responseJson(http.Response response) {
    final contentType = _header(response, 'content-type');
    if (contentType == null ||
        !RegExp(
          r'^application/json(?:\s*;\s*charset=utf-8)?$',
          caseSensitive: false,
        ).hasMatch(contentType)) {
      throw const RepositoryCapabilityException();
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  T _decode(Map<String, dynamic> wire, UuidValue id) {
    final value = serializer.fromJson(wire);
    if (value.id != id || !_same(wire, _wire(value))) {
      throw const RepositoryCapabilityException();
    }
    return value;
  }

  Map<String, dynamic> _wire(T value) {
    final wire =
        jsonDecode(jsonEncode(serializer.toJson(value)))
            as Map<String, dynamic>;
    wire['revision'] = _wireRevision(wire['revision']).value;
    if (wire['id'] != value.id.uuid ||
        wire['revision'] != value.revision.value ||
        wire['createdAt'] != value.createdAt.toIso8601String() ||
        wire['updatedAt'] != value.updatedAt.toIso8601String()) {
      throw const RepositoryCapabilityException();
    }
    return wire;
  }

  RepositoryException _status(int status) => RepositoryException(
    'HTTP operation failed.',
    type: switch (status) {
      400 || 412 || 428 => RepositoryExceptionType.constraint,
      401 => RepositoryExceptionType.unauthorized,
      403 => RepositoryExceptionType.forbidden,
      404 || 410 => RepositoryExceptionType.notFound,
      409 => RepositoryExceptionType.duplicate,
      408 || 504 => RepositoryExceptionType.timeout,
      429 || 502 || 503 => RepositoryExceptionType.connection,
      _ => RepositoryExceptionType.unknown,
    },
  );

  RepositoryException _failure(Object error) => RepositoryException(
    'HTTP operation failed.',
    type: switch (error) {
      RepositoryException(:final type) => type,
      TimeoutException() => RepositoryExceptionType.timeout,
      http.ClientException() => RepositoryExceptionType.connection,
      _ => RepositoryExceptionType.unknown,
    },
  );

  Revision _wireRevision(Object? value) {
    try {
      return Revision.fromJson(value);
    } on FormatException {
      throw const RepositoryCapabilityException();
    }
  }

  bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
    }
    return a == b;
  }
}

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.followRedirects = false;
    return inner.send(request);
  }
}
