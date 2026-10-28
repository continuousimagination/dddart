import 'package:analyzer/dart/element/element.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_repository_sql/dddart_repository_sql.dart';
import 'package:test/test.dart';

void main() {
  test('SQL analysis resolves inherited generic identity and reference types',
      () async {
    final library = await resolveSource(
      '''
library identity_types;
import 'package:dddart/dddart.dart' show Identity, AggregateRoot;
class NativeId extends Identity {
  const NativeId(this.value);
  final String value;
  @override List<Object?> get props => [value];
}
abstract class State<I extends Identity> extends AggregateRoot<I> {
  State({required super.id,required this.reference});
  final I reference;
}
class Issue extends State<NativeId> {
  Issue({required super.id,required super.reference});
}
''',
      (resolver) async => (await resolver.findLibraryByName('identity_types'))!,
    );
    final issue = library.topLevelElements
        .whereType<ClassElement>()
        .firstWhere((e) => e.name == 'Issue');
    final state = library.topLevelElements
        .whereType<ClassElement>()
        .firstWhere((e) => e.name == 'State');
    final identity = IdentityTypeAnalysis.identityOf(issue);
    expect(identity.getDisplayString(withNullability: false), 'NativeId');
    expect(IdentityTypeAnalysis.isIdentity(identity), isTrue);
    final reference =
        state.fields.firstWhere((field) => field.name == 'reference');
    expect(
      IdentityTypeAnalysis.fieldType(issue, reference)
          .getDisplayString(withNullability: false),
      'NativeId',
    );
  });
}
