/// Generates explicit event registrations in the owning combined Dart part.
library;

// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_events_distributed/src/event_registry.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:source_gen/source_gen.dart';

/// Combines registry declarations with the JSON builder's serializer output.
Builder eventRegistryBuilder(BuilderOptions options) => SharedPartBuilder(
      [EventRegistryGenerator()],
      'event_registry',
    );

/// Registers concrete annotated event serializers with explicit stable keys.
class EventRegistryGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final events = <ClassElement>[];
    for (final annotated
        in library.annotatedWith(const TypeChecker.fromRuntime(Serializable))) {
      final element = annotated.element;
      if (element is ClassElement &&
          element.allSupertypes.any((type) =>
              const TypeChecker.fromRuntime(DomainEvent)
                  .isExactly(type.element))) {
        final eventType = element.allSupertypes.firstWhere((type) =>
            const TypeChecker.fromRuntime(DomainEvent).isExactly(type.element));
        final identity = eventType.typeArguments.single;
        if (element.typeParameters.isNotEmpty ||
            identity is! InterfaceType ||
            const TypeChecker.fromRuntime(Identity)
                .isExactly(identity.element)) {
          throw InvalidGenerationSourceError(
              'Distributed events require a concrete aggregate identity type.',
              element: element);
        }
        events.add(element);
      }
    }
    if (events.isEmpty) return null;
    events.sort((a, b) => a.name.compareTo(b.name));
    final keys = <String>{};
    final buffer = StringBuffer()
      ..writeln(
          '/// Creates fresh event registrations sharing the supplied identity codecs.')
      ..writeln(
          'EventRegistry createGeneratedEventRegistry({IdentityCodecRegistry? identityCodecs}) {')
      ..writeln(
          '  final registry = EventRegistry(identityCodecs: identityCodecs);');
    for (final event in events) {
      final annotation = const TypeChecker.fromRuntime(DistributedEvent)
          .firstAnnotationOf(event);
      final key = annotation == null
          ? event.name
          : ConstantReader(annotation).read('key').stringValue;
      if (key.isEmpty || key.trim() != key || !keys.add(key)) {
        throw InvalidGenerationSourceError(
            'Duplicate or invalid distributed event key.',
            element: event);
      }
      final literal = _literal(key);
      buffer.writeln(
          '  registry.registerSerializer<${event.name}>($literal, ${event.name}JsonSerializer.withIdentityCodecs(registry.identityCodecs));');
    }
    buffer
      ..writeln('  return registry;')
      ..writeln('}');
    return buffer.toString();
  }

  String _literal(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', r'\r')}'";
}
