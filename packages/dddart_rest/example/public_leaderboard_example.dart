// ignore_for_file: avoid_print

// Finite local demonstration: public reads and protected writes share a resource.
// Demo credentials are deliberately local fixtures. Supply JwtAuthHandler or
// OAuthJwtAuthHandler in an application; the access policies stay the same.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dddart/dddart.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'authorization_example.dart' as documents;
import 'lib/json_serializer_support.dart';

class Score extends AggregateRoot<UuidValue> {
  Score({
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
    required this.player,
    required this.points,
  }) : super(id: id ?? UuidValue.generate());
  final String player;
  final int points;
}

Score snapshotScore(Score value) => Score(
      id: value.id,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
      player: value.player,
      points: value.points,
    );

class ScoreSerializer extends ExampleJsonSerializer<Score> {
  @override
  String serialize(Score value, [SerializationConfig? config]) => jsonEncode({
        'id': value.id.uuid,
        'player': value.player,
        'points': value.points,
      });
  @override
  Score deserialize(String data, [SerializationConfig? config]) {
    final value = jsonDecode(data) as Map<String, dynamic>;
    return Score(
      id: UuidValue.fromString(value['id'] as String),
      player: value['player'] as String,
      points: value['points'] as int,
    );
  }
}

class ScoreRepository extends InMemoryConditionalRepository<Score, UuidValue> {
  ScoreRepository() : super(clone: snapshotScore);
  final _ids = <UuidValue>{};
  @override
  Future<void> save(Score value) async {
    await super.save(value);
    _ids.add(value.id);
  }

  @override
  Future<String> saveConditional(
    Score value, {
    required ExpectedRevision expected,
  }) async {
    final revision = await super.saveConditional(value, expected: expected);
    _ids.add(value.id);
    return revision;
  }

  @override
  Future<void> deleteById(UuidValue id) async {
    await super.deleteById(id);
    _ids.remove(id);
  }

  @override
  Future<void> deleteConditional(
    UuidValue id, {
    required ExpectedRevision expected,
  }) async {
    await super.deleteConditional(id, expected: expected);
    _ids.remove(id);
  }

  Future<List<Score>> all() => Future.wait(_ids.map(getById));
}

class DemoVerifier implements AuthenticationHandler<documents.UserClaims> {
  @override
  Future<AuthenticationResult<documents.UserClaims>> authenticate(
    Request request,
  ) async {
    final claims = switch (request.headers['authorization']) {
      'Bearer local-alice' =>
        const documents.UserClaims(userId: 'alice', username: 'Alice'),
      'Bearer local-bob' =>
        const documents.UserClaims(userId: 'bob', username: 'Bob'),
      'Bearer local-moderator' => const documents.UserClaims(
          userId: 'moderator',
          username: 'Moderator',
          isAdmin: true,
        ),
      _ => null,
    };
    return claims == null
        ? AuthenticationResult.failure('Invalid demo credential')
        : AuthenticationResult.success(userId: claims.userId, claims: claims);
  }
}

class ScorePolicy
    implements AuthorizationHandler<Score, UuidValue, documents.UserClaims> {
  @override
  Future<AuthorizationResult> authorize(
    AuthorizationContext<Score, UuidValue, documents.UserClaims> context,
  ) async {
    final claims = context.caller.claims;
    final allowed = switch (context) {
      ReadContext<Score, UuidValue, documents.UserClaims>() => true,
      QueryContext<Score, UuidValue, documents.UserClaims>() => true,
      CreateContext<Score, UuidValue, documents.UserClaims>() =>
        claims != null &&
            context.proposed.player == claims.userId &&
            context.proposed.points >= 0 &&
            context.proposed.points <= 100,
      UpdateContext<Score, UuidValue, documents.UserClaims>() =>
        (claims?.isAdmin ?? false) &&
            context.proposed.points >= 0 &&
            context.proposed.points <= 100,
      DeleteContext<Score, UuidValue, documents.UserClaims>() =>
        claims?.isAdmin ?? false,
    };
    return allowed
        ? const AuthorizationResult.allow(scope: UnrestrictedQueryScope())
        : const AuthorizationResult.deny();
  }
}

void requireStatus(http.Response response, int expected) {
  if (response.statusCode != expected) {
    throw StateError(
      'Expected $expected, got ${response.statusCode}: ${response.body}',
    );
  }
}

Future<void> main() async {
  final scores = ScoreRepository();
  final scoreSerializer = ScoreSerializer();
  final verifier = DemoVerifier();
  final scorePolicy =
      AccessPolicy<Score, UuidValue, documents.UserClaims>.custom(
    ScorePolicy(),
    authentication: AuthenticationRequirement.required,
  );
  final leaderboard = CrudResource<Score, UuidValue, documents.UserClaims>(
    path: '/leaderboard',
    repository: scores,
    serializer: scoreSerializer,
    authorizationSnapshot: snapshotScore,
    authenticationHandler: verifier,
    defaultPolicy: scorePolicy,
    operationPolicies: {
      CrudOperation.read: const AccessPolicy.public(),
      CrudOperation.query: const AccessPolicy.public(),
    },
    collectionHandler: (repo, filters, skip, take, authorization) async {
      final ranked = await scores.all()
        ..sort((a, b) => b.points.compareTo(a.points));
      return QueryResult(
        ranked.skip(skip).take(take).toList(),
        totalCount: ranked.length,
      );
    },
  );

  final privateDocuments = documents.DocumentRepository();
  final private = documents.Document(
    id: UuidValue.generate(),
    title: 'Private',
    content: 'Alice only',
    ownerId: 'alice',
  );
  final public = documents.Document(
    id: UuidValue.generate(),
    title: 'Public',
    content: 'Everyone',
    ownerId: 'bob',
    isPublic: true,
  );
  await privateDocuments.save(private);
  await privateDocuments.save(public);
  final documentPolicy = documents.DocumentAuthorizationHandler();
  final documentResource =
      CrudResource<documents.Document, UuidValue, documents.UserClaims>(
    path: '/documents',
    repository: privateDocuments,
    serializer: documents.DocumentSerializer(),
    authorizationSnapshot: documents.snapshotDocument,
    authenticationHandler: verifier,
    defaultPolicy: AccessPolicy.custom(
      documentPolicy,
      authentication: AuthenticationRequirement.required,
    ),
    operationPolicies: {
      CrudOperation.read: AccessPolicy.custom(documentPolicy),
      CrudOperation.query: AccessPolicy.custom(documentPolicy),
    },
    collectionHandler: documents.documentQuery,
    queryHandlers: {'ownerId': documents.documentQuery},
  );

  // A separate resource intentionally exposes public CRUD, without a verifier.
  final open = CrudResource<Score, UuidValue, void>(
    path: '/open',
    repository: InMemoryRepository<Score, UuidValue>(),
    serializer: scoreSerializer,
  );
  final app = HttpServer()
    ..registerResource(leaderboard)
    ..registerResource(documentResource)
    ..registerResource(open);
  final server = await shelf_io.serve(
    app.buildHandler(),
    io.InternetAddress.loopbackIPv4,
    0,
  );
  final client = http.Client();
  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');
  Map<String, String> headers([String? token]) => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };
  try {
    final score = Score(player: 'alice', points: 42);
    requireStatus(
      await client.post(
        uri('/leaderboard'),
        headers: headers(),
        body: scoreSerializer.serialize(score),
      ),
      401,
    );
    requireStatus(
      await client.post(
        uri('/leaderboard'),
        headers: headers('local-alice'),
        body: scoreSerializer.serialize(score),
      ),
      201,
    );
    requireStatus(await client.get(uri('/leaderboard')), 200);
    requireStatus(await client.get(uri('/leaderboard/${score.id}')), 200);
    final correction = Score(id: score.id, player: score.player, points: 50);
    requireStatus(
      await client.put(
        uri('/leaderboard/${score.id}'),
        headers: headers('local-alice'),
        body: scoreSerializer.serialize(correction),
      ),
      403,
    );
    requireStatus(
      await client.put(
        uri('/leaderboard/${score.id}'),
        headers: headers('local-moderator'),
        body: scoreSerializer.serialize(correction),
      ),
      200,
    );
    requireStatus(
      await client.delete(
        uri('/leaderboard/${score.id}'),
        headers: headers('local-moderator'),
      ),
      204,
    );
    print(
      'Anonymous leaderboard reads work; submissions need identity and corrections/deletions need moderator permission.',
    );

    requireStatus(await client.get(uri('/documents/${private.id}')), 403);
    requireStatus(await client.get(uri('/documents/${public.id}')), 200);
    final anonymousPage = await client.get(uri('/documents?skip=0&take=1'));
    requireStatus(anonymousPage, 200);
    if (anonymousPage.headers['x-total-count'] != '1' ||
        anonymousPage.body.contains('Alice only')) {
      throw StateError('Anonymous document scope leaked private data/count');
    }
    final narrowed = await client.get(uri('/documents?ownerId=alice'));
    requireStatus(narrowed, 200);
    if (narrowed.headers['x-total-count'] != '0') {
      throw StateError('Request filter widened scope');
    }
    final own =
        await client.get(uri('/documents'), headers: headers('local-alice'));
    requireStatus(own, 200);
    if (own.headers['x-total-count'] != '2') {
      throw StateError('Owner/public scope missing');
    }
    print(
      'Public documents remain anonymous; private rows and counts follow verified scope.',
    );

    final openScore = Score(player: 'anonymous', points: 7);
    requireStatus(
      await client.post(
        uri('/open'),
        headers: headers(),
        body: scoreSerializer.serialize(openScore),
      ),
      201,
    );
    requireStatus(await client.get(uri('/open/${openScore.id}')), 200);
    requireStatus(
      await client.put(
        uri('/open/${openScore.id}'),
        headers: headers(),
        body: scoreSerializer.serialize(openScore),
      ),
      200,
    );
    requireStatus(await client.delete(uri('/open/${openScore.id}')), 204);
    print(
      'Unconfigured public CRUD works without authentication or a fabricated identity.',
    );
  } finally {
    client.close();
    await server.close(force: true);
  }
}
