import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dddart/dddart.dart';
import 'package:source_gen/source_gen.dart';

/// Type-based identity analysis shared by SQL schema and repository builders.
abstract final class IdentityTypeAnalysis {
  /// Public stored fields through the consuming class's superclass chain.
  static List<FieldElement> instanceFields(ClassElement owner) {
    final fields = <String, FieldElement>{};
    for (final type in [owner.thisType, ...owner.allSupertypes]) {
      for (final field in type.element.fields) {
        if (!field.isStatic && !field.isSynthetic && !field.isPrivate) {
          fields.putIfAbsent(field.name, () => field);
        }
      }
    }
    return fields.values.toList();
  }

  /// Whether the resolved field type is an actual framework identity subtype.
  static bool isIdentity(DartType type) =>
      const TypeChecker.fromRuntime(Identity).isAssignableFromType(type);

  /// Resolves Entity<I> through concrete application/convenience ancestors.
  static InterfaceType identityOf(ClassElement element) {
    final entity = element.allSupertypes
        .where(
          (type) =>
              const TypeChecker.fromRuntime(Entity).isExactly(type.element),
        )
        .firstOrNull;
    final identity = entity?.typeArguments.single;
    if (element.typeParameters.isNotEmpty ||
        identity is! InterfaceType ||
        const TypeChecker.fromRuntime(Identity).isExactly(identity.element)) {
      throw InvalidGenerationSourceError(
        'SQL entities require a concrete identity type.',
        element: element,
      );
    }
    return identity;
  }

  /// Resolves inherited field types with the consuming class's type arguments.
  static DartType fieldType(ClassElement owner, FieldElement field) {
    for (final type in [owner.thisType, ...owner.allSupertypes]) {
      if (type.element == field.enclosingElement) {
        return type.getGetter(field.name)?.returnType ?? field.type;
      }
    }
    return field.type;
  }
}
