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

    test('should scan for @Serializable DomainEvent<UuidValue> subclasses',
        () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class UserCreatedEvent extends DomainEvent<UuidValue> {
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
class OrderPlacedEvent extends DomainEvent<UuidValue> {
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
      expect(output, contains('createGeneratedEventRegistry'));
      expect(output, contains('UserCreatedEvent'));
      expect(output, contains('OrderPlacedEvent'));
      expect(
        output,
        contains('UserCreatedEventJsonSerializer.withIdentityCodecs'),
      );
      expect(
        output,
        contains('OrderPlacedEventJsonSerializer.withIdentityCodecs'),
      );
    });

    test('should generate registry map with correct structure', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestEvent extends DomainEvent<UuidValue> {
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
          'EventRegistry createGeneratedEventRegistry({IdentityCodecRegistry? identityCodecs})',
        ),
      );
      expect(
        output,
        contains("registry.registerSerializer<TestEvent>('TestEvent',"),
      );
      expect(output, contains('return registry;'));
    });

    test('should handle multiple event types', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class EventA extends DomainEvent<UuidValue> {
  EventA({required super.aggregateId});
  static EventA fromJson(Map<String, dynamic> json) {
    return EventA(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class EventB extends DomainEvent<UuidValue> {
  EventB({required super.aggregateId});
  static EventB fromJson(Map<String, dynamic> json) {
    return EventB(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class EventC extends DomainEvent<UuidValue> {
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
      expect(output, contains('EventAJsonSerializer.withIdentityCodecs'));
      expect(output, contains('EventBJsonSerializer.withIdentityCodecs'));
      expect(output, contains('EventCJsonSerializer.withIdentityCodecs'));
    });

    test(
        'should ignore @Serializable classes that do not extend DomainEvent<UuidValue>',
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
class MyEvent extends DomainEvent<UuidValue> {
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

class MyEvent extends DomainEvent<UuidValue> {
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
class TestEvent extends DomainEvent<UuidValue> {
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
      expect(output, contains('/// Creates fresh event registrations'));
      expect(
        output,
        contains('sharing the supplied identity codecs'),
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
class ZebraEvent extends DomainEvent<UuidValue> {
  ZebraEvent({required super.aggregateId});
  static ZebraEvent fromJson(Map<String, dynamic> json) {
    return ZebraEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class AppleEvent extends DomainEvent<UuidValue> {
  AppleEvent({required super.aggregateId});
  static AppleEvent fromJson(Map<String, dynamic> json) {
    return AppleEvent(
      aggregateId: UuidValue.fromString(json['aggregateId'] as String),
    );
  }
}

@Serializable()
class MangoEvent extends DomainEvent<UuidValue> {
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

    test('combined part declarations use owning-library imports', () async {
      final library = await resolveSource(
        '''
library test;

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

@Serializable()
class TestEvent extends DomainEvent<UuidValue> {
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
      expect(output, isNot(contains("import '")));
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
