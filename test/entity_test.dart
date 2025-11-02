import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import '../lib/src/entity.dart';

// Concrete implementation of Entity for testing
class TestEntity extends Entity {
  TestEntity({
    UuidValue? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);
}

void main() {
  group('Entity', () {
    group('constructor', () {
      test('creates entity with auto-generated ID when ID not provided', () {
        final entity = TestEntity();
        
        expect(entity.id, isA<UuidValue>());
        expect(entity.id.uuid, isNotEmpty);
      });

      test('creates entity with provided ID', () {
        final providedId = UuidValue.fromString(const Uuid().v4());
        final entity = TestEntity(id: providedId);
        
        expect(entity.id, equals(providedId));
      });

      test('creates entity with auto-generated timestamps when not provided', () {
        final beforeCreation = DateTime.now();
        final entity = TestEntity();
        final afterCreation = DateTime.now();
        
        expect(entity.createdAt.isAfter(beforeCreation.subtract(const Duration(seconds: 1))), isTrue);
        expect(entity.createdAt.isBefore(afterCreation.add(const Duration(seconds: 1))), isTrue);
        expect(entity.updatedAt.isAfter(beforeCreation.subtract(const Duration(seconds: 1))), isTrue);
        expect(entity.updatedAt.isBefore(afterCreation.add(const Duration(seconds: 1))), isTrue);
      });

      test('creates entity with provided timestamps', () {
        final createdAt = DateTime(2023, 1, 1);
        final updatedAt = DateTime(2023, 1, 2);
        final entity = TestEntity(createdAt: createdAt, updatedAt: updatedAt);
        
        expect(entity.createdAt, equals(createdAt));
        expect(entity.updatedAt, equals(updatedAt));
      });

      test('creates entity with mixed provided and auto-generated parameters', () {
        final providedId = UuidValue.fromString(const Uuid().v4());
        final createdAt = DateTime(2023, 1, 1);
        final beforeCreation = DateTime.now();
        final entity = TestEntity(id: providedId, createdAt: createdAt);
        final afterCreation = DateTime.now();
        
        expect(entity.id, equals(providedId));
        expect(entity.createdAt, equals(createdAt));
        expect(entity.updatedAt.isAfter(beforeCreation.subtract(const Duration(seconds: 1))), isTrue);
        expect(entity.updatedAt.isBefore(afterCreation.add(const Duration(seconds: 1))), isTrue);
      });
    });

    group('equality and hashCode', () {
      test('entities with same ID are equal', () {
        final id = UuidValue.fromString(const Uuid().v4());
        final entity1 = TestEntity(id: id);
        final entity2 = TestEntity(id: id);
        
        expect(entity1, equals(entity2));
        expect(entity1.hashCode, equals(entity2.hashCode));
      });

      test('entities with different IDs are not equal', () {
        final entity1 = TestEntity();
        final entity2 = TestEntity();
        
        expect(entity1, isNot(equals(entity2)));
        expect(entity1.hashCode, isNot(equals(entity2.hashCode)));
      });

      test('entity is equal to itself', () {
        final entity = TestEntity();
        
        expect(entity, equals(entity));
        expect(entity.hashCode, equals(entity.hashCode));
      });

      test('entity is not equal to null', () {
        final entity = TestEntity();
        
        expect(entity, isNot(equals(null)));
      });

      test('entity is not equal to different type', () {
        final entity = TestEntity();
        
        expect(entity, isNot(equals('not an entity')));
      });
    });

    group('touch method', () {
      test('updates updatedAt timestamp', () {
        final entity = TestEntity(updatedAt: DateTime(2023, 1, 1));
        final originalUpdatedAt = entity.updatedAt;
        
        // Wait a small amount to ensure timestamp difference
        Future.delayed(const Duration(milliseconds: 1), () {
          entity.touch();
          
          expect(entity.updatedAt.isAfter(originalUpdatedAt), isTrue);
        });
      });

      test('does not change createdAt timestamp', () {
        final createdAt = DateTime(2023, 1, 1);
        final entity = TestEntity(createdAt: createdAt);
        
        entity.touch();
        
        expect(entity.createdAt, equals(createdAt));
      });

      test('does not change ID', () {
        final id = UuidValue.fromString(const Uuid().v4());
        final entity = TestEntity(id: id);
        
        entity.touch();
        
        expect(entity.id, equals(id));
      });
    });

    group('toString', () {
      test('returns string representation with type and ID', () {
        final entity = TestEntity();
        final result = entity.toString();
        
        expect(result, contains('TestEntity'));
        expect(result, contains('id:'));
        expect(result, contains(entity.id.toString()));
      });
    });
  });
}