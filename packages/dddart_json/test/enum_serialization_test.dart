import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:test/test.dart';

import 'test_models.dart';

void main() {
  group('Enum Serialization', () {
    test('should serialize enum to string name', () {
      final game = TestGame(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        state: GameState.inProgress,
        createdAt: DateTime.parse('2025-01-19T12:00:00Z'),
        updatedAt: DateTime.parse('2025-01-19T12:00:00Z'),
      );

      final serializer = TestGameJsonSerializer();
      final json = serializer.toJson(game);

      // Should contain "inProgress" as a string, not the enum object
      expect(json['state'], equals('inProgress'));
      expect(json['state'], isA<String>());
    });

    test('should deserialize string name to enum', () {
      final jsonMap = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'state': 'inProgress',
        'createdAt': '2025-01-19T12:00:00Z',
        'updatedAt': '2025-01-19T12:00:00Z',
      };

      final serializer = TestGameJsonSerializer();
      final game = serializer.fromJson(jsonMap);

      expect(game.state, equals(GameState.inProgress));
    });

    test('should serialize and deserialize all enum values', () {
      final serializer = TestGameJsonSerializer();

      for (final state in GameState.values) {
        final game = TestGame(
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
          state: state,
          createdAt: DateTime.parse('2025-01-19T12:00:00Z'),
          updatedAt: DateTime.parse('2025-01-19T12:00:00Z'),
        );

        final json = serializer.toJson(game);
        expect(json['state'], equals(state.name));

        final deserialized = serializer.fromJson(json);
        expect(deserialized.state, equals(state));
      }
    });

    test('should serialize enum to valid JSON string', () {
      final game = TestGame(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        state: GameState.completed,
        createdAt: DateTime.parse('2025-01-19T12:00:00Z'),
        updatedAt: DateTime.parse('2025-01-19T12:00:00Z'),
      );

      final serializer = TestGameJsonSerializer();
      final jsonString = serializer.serialize(game);

      // Should be valid JSON
      expect(() => jsonDecode(jsonString), returnsNormally);

      // Should contain the enum as a string
      expect(jsonString, contains('"state":"completed"'));
    });

    test('should deserialize JSON string with enum', () {
      const jsonString = '''
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "state": "waitingForPlayers",
        "createdAt": "2025-01-19T12:00:00Z",
        "updatedAt": "2025-01-19T12:00:00Z"
      }
      ''';

      final serializer = TestGameJsonSerializer();
      final game = serializer.deserialize(jsonString);

      expect(game.state, equals(GameState.waitingForPlayers));
    });

    test('should handle nullable enum fields', () {
      const player = TestPlayer(
        name: 'Alice',
        role: PlayerRole.admin,
      );

      final serializer = TestPlayerJsonSerializer();
      final json = serializer.toJson(player);

      expect(json['role'], equals('admin'));
      expect(json.containsKey('status'), isFalse);

      final deserialized = serializer.fromJson(json);
      expect(deserialized.role, equals(PlayerRole.admin));
      expect(deserialized.status, isNull);
    });

    test('should serialize nullable enum when present', () {
      const player = TestPlayer(
        name: 'Bob',
        role: PlayerRole.player,
        status: PlayerStatus.active,
      );

      final serializer = TestPlayerJsonSerializer();
      final json = serializer.toJson(player);

      expect(json['status'], equals('active'));

      final deserialized = serializer.fromJson(json);
      expect(deserialized.status, equals(PlayerStatus.active));
    });

    test('should throw on invalid enum value during deserialization', () {
      final jsonMap = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'state': 'invalidState',
        'createdAt': '2025-01-19T12:00:00Z',
        'updatedAt': '2025-01-19T12:00:00Z',
      };

      final serializer = TestGameJsonSerializer();

      expect(
        () => serializer.fromJson(jsonMap),
        throwsA(isA<DeserializationException>()),
      );
    });
  });
}
