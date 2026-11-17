import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'external consumer uses typed native policies and query scopes',
    () async {
      final packageRoot = Directory.current;
      final packagesRoot = packageRoot.parent;
      final fixture =
          Directory.systemTemp.createTempSync('dddart_rest_policy_consumer_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: policy_consumer
publish_to: none
environment:
  sdk: '>=3.5.0 <4.0.0'
dependencies:
  dddart: any
  dddart_json: any
  dddart_rest:
    path: ${packageRoot.path}
  dddart_serialization: any
dependency_overrides:
  dddart:
    path: ${packagesRoot.path}/dddart
  dddart_json:
    path: ${packagesRoot.path}/dddart_json
  dddart_serialization:
    path: ${packagesRoot.path}/dddart_serialization
''');
      Directory('${fixture.path}/bin').createSync();
      File('${fixture.path}/bin/main.dart').writeAsStringSync('''
import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_rest/dddart_rest.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

class NativeId extends Identity {
  const NativeId(this.value);
  final String value;
  @override List<Object?> get props => [value];
}
class Record extends AggregateRoot<NativeId> {
  Record(NativeId id, {DateTime? createdAt, DateTime? updatedAt}) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);
}
class Claims {
  const Claims(this.tenant);
  final String tenant;
}
class TenantScope implements QueryScope {
  const TenantScope(this.tenant);
  final String tenant;
}
class Policy implements AuthorizationHandler<Record, NativeId, Claims> {
  @override Future<AuthorizationResult> authorize(
      AuthorizationContext<Record, NativeId, Claims> context) async {
    if (context is QueryContext<Record, NativeId, Claims>) {
      return AuthorizationResult.allow(scope: TenantScope(context.caller.claims!.tenant));
    }
    final NativeId id = switch (context) {
      ReadContext<Record, NativeId, Claims>() => context.current.id,
      CreateContext<Record, NativeId, Claims>() => context.proposed.id,
      UpdateContext<Record, NativeId, Claims>() => context.current.id,
      DeleteContext<Record, NativeId, Claims>() => context.current.id,
      QueryContext<Record, NativeId, Claims>() => throw StateError('handled above'),
    };
    return id.value == 'record/a' ? const AuthorizationResult.allow() : const AuthorizationResult.deny();
  }
}
CrudResource<Record, NativeId, Claims> resource(
    Repository<Record, NativeId> repository, JsonSerializer<Record> serializer,
    IdentityCodecRegistry codecs) => CrudResource<Record, NativeId, Claims>(
  path: '/records', repository: repository, serializer: serializer,
  identityCodecs: codecs, authorizationSnapshot: (record) => Record(record.id, createdAt: record.createdAt, updatedAt: record.updatedAt), defaultPolicy: AccessPolicy.custom(Policy()),
  collectionHandler: (repository, filters, skip, take, authorization) async {
    final Claims? claims = authorization.caller.claims;
    final TenantScope scope = authorization.scope as TenantScope;
    if (claims?.tenant != scope.tenant) throw const AccessDeniedException();
    return QueryResult<Record>([], totalCount: 0);
  },
  preCreate: (record, caller) => record,
);
Future<void> main() async {
  final caller = VerifiedCaller(AuthenticationResult.success(userId: 'alice', claims: const Claims('tenant')));
  final record = Record(const NativeId('record/a'));
  final policy = Policy();
  final result = await policy.authorize(ReadContext(caller: caller, current: record));
  if (!result.isAuthorized) throw StateError('typed read failed');
  final query = await policy.authorize(QueryContext(caller: caller, filters: {}));
  if ((query.scope as TenantScope).tenant != 'tenant') throw StateError('scope lost');
}
''');
      for (final arguments in [
        ['pub', 'get'],
        ['analyze', '--fatal-infos'],
        ['run', 'bin/main.dart'],
      ]) {
        final result = await Process.run(
          Platform.resolvedExecutable,
          arguments,
          workingDirectory: fixture.path,
        );
        expect(
          result.exitCode,
          0,
          reason: '${arguments.join(' ')}\n${result.stdout}\n${result.stderr}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
