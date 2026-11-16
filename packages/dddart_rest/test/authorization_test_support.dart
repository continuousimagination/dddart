import 'dart:async';
import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';

import 'json_serializer_test_support.dart';

class Document extends UuidAggregateRoot {
  Document({
    super.id,
    this.owner = 'alice',
    this.tenant = 'one',
    this.role = 'member',
    this.isPublic = false,
    this.content = 'private content',
  });
  final String owner;
  final String tenant;
  final String role;
  final bool isPublic;
  final String content;
  Document copy({
    String? owner,
    String? tenant,
    String? role,
    bool? isPublic,
    String? content,
  }) =>
      Document(
        id: id,
        owner: owner ?? this.owner,
        tenant: tenant ?? this.tenant,
        role: role ?? this.role,
        isPublic: isPublic ?? this.isPublic,
        content: content ?? this.content,
      );
}

class Claims {
  const Claims(this.user, this.tenant, {this.admin = false});
  final String user;
  final String tenant;
  final bool admin;
}

class DocumentSerializer extends TestJsonSerializer<Document> {
  @override
  String serialize(Document value, [dynamic config]) => jsonEncode({
        'id': value.id.uuid,
        'owner': value.owner,
        'tenant': value.tenant,
        'role': value.role,
        'isPublic': value.isPublic,
        'content': value.content,
      });
  @override
  Document deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return Document(
      id: UuidValue.fromString(json['id'] as String),
      owner: json['owner'] as String,
      tenant: json['tenant'] as String,
      role: json['role'] as String,
      isPublic: json['isPublic'] as bool,
      content: json['content'] as String,
    );
  }
}

Document cloneDocument(Document value) =>
    DocumentSerializer().deserialize(DocumentSerializer().serialize(value));

class Documents extends InMemoryConditionalRepository<Document, UuidValue> {
  Documents({super.eventPublisher}) : super(clone: cloneDocument);
  final ids = <UuidValue>{};
  int reads = 0;
  int writes = 0;
  Future<void> Function()? beforeConditionalSave;
  @override
  Future<VersionedAggregate<Document, UuidValue>> getVersioned(UuidValue id) {
    reads++;
    return super.getVersioned(id);
  }

  @override
  Future<void> save(Document value) async {
    writes++;
    await super.save(value);
    ids.add(value.id);
  }

  @override
  Future<String> saveConditional(
    Document value, {
    required ExpectedRevision expected,
  }) async {
    writes++;
    await beforeConditionalSave?.call();
    final revision = await super.saveConditional(value, expected: expected);
    ids.add(value.id);
    return revision;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    writes++;
    await super.deleteById(id);
    ids.remove(id);
  }

  @override
  Future<void> deleteConditional(
    UuidValue id, {
    required ExpectedRevision expected,
  }) async {
    writes++;
    await super.deleteConditional(id, expected: expected);
    ids.remove(id);
  }

  Future<List<Document>> all() => Future.wait(ids.map(getById));
  void resetCounters() {
    reads = 0;
    writes = 0;
  }
}

class Verifier implements AuthenticationHandler<Claims> {
  int calls = 0;
  @override
  Future<AuthenticationResult<Claims>> authenticate(Request request) async {
    calls++;
    final claims = switch (request.headers['authorization']) {
      'Bearer alice' => const Claims('alice', 'one'),
      'Bearer bob' => const Claims('bob', 'two'),
      'Bearer admin' => const Claims('admin', 'one', admin: true),
      _ => null,
    };
    return claims == null
        ? AuthenticationResult.failure('Invalid credentials')
        : AuthenticationResult.success(userId: claims.user, claims: claims);
  }
}

class Policy implements AuthorizationHandler<Document, UuidValue, Claims> {
  Policy(this.evaluate);
  final FutureOr<AuthorizationResult> Function(
    AuthorizationContext<Document, UuidValue, Claims>,
  ) evaluate;
  final contexts = <AuthorizationContext<Document, UuidValue, Claims>>[];
  @override
  Future<AuthorizationResult> authorize(
    AuthorizationContext<Document, UuidValue, Claims> context,
  ) async {
    contexts.add(context);
    return evaluate(context);
  }
}

class TenantScope implements QueryScope {
  const TenantScope(this.tenant);
  final String tenant;
}

Request request(
  String method, {
  Document? document,
  String? token,
  String path = '/documents',
  Map<String, String> headers = const {},
}) =>
    Request(
      method,
      Uri.parse('http://local$path'),
      headers: {
        if (document != null) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        ...headers,
      },
      body: document == null ? null : DocumentSerializer().serialize(document),
    );
