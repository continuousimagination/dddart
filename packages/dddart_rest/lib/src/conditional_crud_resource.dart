import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/src/authentication_handler.dart';
import 'package:dddart_rest/src/authorization_handler.dart';
import 'package:dddart_rest/src/conditional_headers.dart';
import 'package:dddart_rest/src/http_resource.dart';
import 'package:dddart_rest/src/resource_pipeline.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:shelf/shelf.dart';

/// Conditional CRUD over one stable canonical JSON representation.
///
/// Uses the same admission/decoding/negotiation/error pipeline as ordinary CRUD.
/// No read/check/write sequence, mutable request context or success-PUT validator
/// is introduced. Representation changes require a new API/validator namespace.
class ConditionalCrudResource<T extends VersionedAggregateRoot, TClaims>
    implements HttpResource {
  /// Requires exactly one JSON codec and explicit conditional persistence.
  ConditionalCrudResource({
    required this.path,
    required this.repository,
    required Map<String, Serializer<T>> serializers,
    this.authenticationHandler,
    this.authorizationHandler,
  }) : serializers = Map.unmodifiable(serializers) {
    if (serializers.length != 1 ||
        serializers.keys.single != 'application/json' ||
        serializers.values.single is! JsonSerializer<T>) {
      throw ArgumentError(
        'Conditional resources require one canonical application/json JsonSerializer.',
      );
    }
    _codec = serializers.values.single as JsonSerializer<T>;
    _pipeline = ResourcePipeline(
      path: path,
      serializers: this.serializers,
      authenticationHandler: authenticationHandler,
      authorizationHandler: authorizationHandler,
    );
  }
  @override
  final String path;

  /// Atomic typed persistence boundary.
  final ConditionalRepository<T> repository;

  /// Immutable canonical representation configuration.
  final Map<String, Serializer<T>> serializers;

  /// Trusted optional authentication; absence permits deliberately public use.
  final AuthenticationHandler<TClaims>? authenticationHandler;

  /// Trusted optional operation policy; requires authentication when configured.
  final AuthorizationHandler<T, TClaims>? authorizationHandler;
  late final JsonSerializer<T> _codec;
  late final ResourcePipeline<T, TClaims> _pipeline;

  Map<String, dynamic> _representation(T value) {
    final wire =
        jsonDecode(jsonEncode(_codec.toJson(value))) as Map<String, dynamic>;
    wire['revision'] = _wireRevision(wire['revision']).value;
    if (wire['id'] != value.id.uuid ||
        wire['revision'] != value.revision.value ||
        wire['createdAt'] != value.createdAt.toIso8601String() ||
        wire['updatedAt'] != value.updatedAt.toIso8601String()) {
      throw const RepositoryCapabilityException();
    }
    return wire;
  }

  @override
  Future<Response> handleGetById(Request request, String id) =>
      _pipeline.run(request, 'Retrieving', (principal) async {
        final uuid = UuidValue.fromString(id);
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeRead(uuid, auth),
          includeMessage: false,
        );
        if (denied != null) return denied;
        final representation = _pipeline.select(request.headers['accept']);
        final value = await repository.getById(uuid);
        return _pipeline.respond(
          value,
          representation,
          expectedId: uuid,
          validate: () {
            _representation(value);
            if (value.revision.value == 0) throw StateError('Unpersisted read');
          },
          etag: () => ConditionalHeaders.etag(value.revision),
        );
      });
  @override
  Future<Response> handleUpdate(
    Request request,
    String id,
  ) => _pipeline.run(request, 'Updating', (principal) async {
    final uuid = UuidValue.fromString(id);
    final condition = ConditionalHeaders.parseWrite(request.headers);
    final expected = switch (condition) {
      AbsentWritePrecondition() => const Revision.zero(),
      RevisionWritePrecondition(:final revision) => revision,
    };
    Map<String, dynamic>? input;
    final value = await _pipeline.deserialize(
      request,
      validateInput: (body) {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic> ||
            decoded['id'] is! String ||
            decoded['createdAt'] is! String ||
            decoded['updatedAt'] is! String) {
          throw const FormatException('Incomplete conditional representation');
        }
        input = decoded;
        decoded['revision'] = Revision.fromJson(decoded['revision']).value;
      },
    );
    if (value.id != uuid ||
        input!['id'] != uuid.uuid ||
        value.revision != expected ||
        input!['revision'] != expected.value ||
        DateTime.parse(input!['createdAt'] as String) != value.createdAt ||
        DateTime.parse(input!['updatedAt'] as String) != value.updatedAt) {
      throw const FormatException(
        'Conditional representation does not match its request',
      );
    }
    final denied = await _pipeline.authorize(
      principal,
      (policy, auth) => condition is AbsentWritePrecondition
          ? policy.authorizeCreate(value, auth)
          : policy.authorizeUpdate(value, auth),
    );
    if (denied != null) return denied;
    final representation = _pipeline.select(request.headers['accept']);
    final next = expected.next();
    final expectedBody = {..._representation(value), 'revision': next.value};
    final accepted = await _pipeline.persist(
      () => repository.save(value, precondition: condition),
    );
    return _pipeline.respond(
      accepted,
      representation,
      status: condition is AbsentWritePrecondition ? 201 : 200,
      expectedId: uuid,
      validate: () {
        if (accepted.revision != next ||
            !_same(expectedBody, _representation(accepted))) {
          throw StateError('Invalid accepted representation');
        }
      },
    );
  });
  @override
  Future<Response> handleDelete(Request request, String id) =>
      _pipeline.run(request, 'Deleting', (principal) async {
        final uuid = UuidValue.fromString(id);
        final condition = ConditionalHeaders.parseWrite(
          request.headers,
          allowCreate: false,
        );
        final denied = await _pipeline.authorize(
          principal,
          (policy, auth) => policy.authorizeDelete(uuid, auth),
        );
        if (denied != null) return denied;
        _pipeline.select(request.headers['accept']);
        if ((await request.readAsString()).isNotEmpty) {
          throw const FormatException('DELETE body is unsupported');
        }
        (condition as RevisionWritePrecondition).revision.next();
        await _pipeline.persist(
          () => repository.deleteById(uuid, precondition: condition),
        );
        return Response(204);
      });
  @override
  Future<Response> handleCreate(Request request) => _pipeline.run(
    request,
    'Creating',
    (_) async => throw const RepositoryCapabilityException(),
  );
  @override
  Future<Response> handleQuery(Request request) => _pipeline.run(
    request,
    'Querying',
    (_) async => throw const RepositoryCapabilityException(),
  );

  bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(
            a.length,
            (index) => index,
          ).every((index) => _same(a[index], b[index]));
    }
    return a == b;
  }

  Revision _wireRevision(Object? value) {
    try {
      return Revision.fromJson(value);
    } on FormatException {
      throw const RepositoryCapabilityException();
    }
  }
}
