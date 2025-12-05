/// Unit tests for event registry generator.
@Tags(['generator'])
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dddart_events_distributed/src/generators/event_registry_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('EventRegistryGenerator', () {
    late EventRegistryGenerator generator;

    setUp(() {
      generator = EventRegistryGenerator();
    });

    tearDown(() async {
      // Give the build system time to clean up file handles
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('should scan for @Serializable DomainEvent subclasses', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class UserCreatedEvent extends DomainEvent {
  UserCreatedEvent({
    required super.aggregateId,
    required this.email,
  });
  
  final String email;
  
  static UserCreatedEvent fromJson(Map<String, dynamic> json) {
    return UserCreatedEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      email: json['email'] as String,
    );
  }
}

@Serializable()
class OrderPlacedEvent extends DomainEvent {
  OrderPlacedEvent({
    required super.aggregateId,
    required this.amount,
  });
  
  final double amount;
  
  static OrderPlacedEvent fromJson(Map<String, dynamic> json) {
    return OrderPlacedEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
      amount: json['amount'] as double,
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(output, contains('generatedEventRegistry'));
      expect(output, contains('UserCreatedEvent'));
      expect(output, contains('OrderPlacedEvent'));
      expect(output, contains('UserCreatedEvent.fromJson'));
      expect(output, contains('OrderPlacedEvent.fromJson'));
    });

    test('should generate registry map with correct structure', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestEvent extends DomainEvent {
  TestEvent({required super.aggregateId});
  
  static TestEvent fromJson(Map<String, dynamic> json) {
    return TestEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(
        output,
        contains(
          'final generatedEventRegistry = '
          '<String, DomainEvent Function(Map<String, dynamic>)>{',
        ),
      );
      expect(output, contains("'TestEvent': TestEvent.fromJson,"));
      expect(output, contains('};'));
    });

    test('should handle multiple event types', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class EventA extends DomainEvent {
  EventA({required super.aggregateId});
  static EventA fromJson(Map<String, dynamic> json) {
    return EventA(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class EventB extends DomainEvent {
  EventB({required super.aggregateId});
  static EventB fromJson(Map<String, dynamic> json) {
    return EventB(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class EventC extends DomainEvent {
  EventC({required super.aggregateId});
  static EventC fromJson(Map<String, dynamic> json) {
    return EventC(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(output, contains('EventA'));
      expect(output, contains('EventB'));
      expect(output, contains('EventC'));
      expect(output, contains('EventA.fromJson'));
      expect(output, contains('EventB.fromJson'));
      expect(output, contains('EventC.fromJson'));
    });

    test('should ignore @Serializable classes that do not extend DomainEvent',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class NotAnEvent {
  NotAnEvent({required this.value});
  final String value;
}

@Serializable()
class MyEvent extends DomainEvent {
  MyEvent({required super.aggregateId});
  static MyEvent fromJson(Map<String, dynamic> json) {
    return MyEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(output, contains('MyEvent'));
      expect(output, isNot(contains('NotAnEvent')));
    });

    test('should return null when no @Serializable DomainEvents found',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class NotAnEvent {
  NotAnEvent({required this.value});
  final String value;
}

class MyEvent extends DomainEvent {
  MyEvent({required super.aggregateId});
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNull);
    });

    test('should include documentation comments in generated code', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestEvent extends DomainEvent {
  TestEvent({required super.aggregateId});
  static TestEvent fromJson(Map<String, dynamic> json) {
    return TestEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(output, contains('/// Generated event registry'));
      expect(
        output,
        contains('/// This map is automatically generated by scanning'),
      );
    });

    test('should sort event classes alphabetically for deterministic output',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class ZebraEvent extends DomainEvent {
  ZebraEvent({required super.aggregateId});
  static ZebraEvent fromJson(Map<String, dynamic> json) {
    return ZebraEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class AppleEvent extends DomainEvent {
  AppleEvent({required super.aggregateId});
  static AppleEvent fromJson(Map<String, dynamic> json) {
    return AppleEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class MangoEvent extends DomainEvent {
  MangoEvent({required super.aggregateId});
  static MangoEvent fromJson(Map<String, dynamic> json) {
    return MangoEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);

      // Verify alphabetical ordering
      final appleIndex = output!.indexOf('AppleEvent');
      final mangoIndex = output.indexOf('MangoEvent');
      final zebraIndex = output.indexOf('ZebraEvent');

      expect(appleIndex, lessThan(mangoIndex));
      expect(mangoIndex, lessThan(zebraIndex));
    });

    test('should include proper imports in generated code', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestEvent extends DomainEvent {
  TestEvent({required super.aggregateId});
  static TestEvent fromJson(Map<String, dynamic> json) {
    return TestEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}
''',
        (resolver) async => (await resolver.findLibraryByName('test'))!,
      );

      final output = generator.generate(
        LibraryReader(library),
        _mockBuildStep(),
      );

      expect(output, isNotNull);
      expect(output, contains("import 'package:dddart/dddart.dart';"));
    });
  });
}

/// Creates a stub BuildStep for testing.
/// Since BuildStep is sealed and we don't actually use it in the generator,
/// we suppress the warning and return a stub instance.
// ignore: subtype_of_sealed_class
BuildStep _mockBuildStep() => _StubBuildStep();

// ignore: subtype_of_sealed_class
class _StubBuildStep implements BuildStep {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
