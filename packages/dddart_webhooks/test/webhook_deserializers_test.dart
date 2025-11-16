import 'package:dddart_webhooks/dddart_webhooks.dart';
import 'package:test/test.dart';

// Test models
class TestEvent {
  TestEvent({required this.id, required this.type});

  factory TestEvent.fromJson(Map<String, dynamic> json) {
    return TestEvent(
      id: json['id'] as String,
      type: json['type'] as String,
    );
  }

  final String id;
  final String type;
}

class TestFormData {
  TestFormData({required this.command, required this.text});

  factory TestFormData.fromForm(Map<String, String> form) {
    return TestFormData(
      command: form['command']!,
      text: form['text'] ?? '',
    );
  }

  final String command;
  final String text;
}

void main() {
  group('WebhookDeserializers', () {
    group('json', () {
      test('should deserialize valid JSON payload', () {
        const body = '{"id": "123", "type": "user.created"}';

        final event = WebhookDeserializers.json(body, TestEvent.fromJson);

        expect(event.id, equals('123'));
        expect(event.type, equals('user.created'));
      });

      test('should deserialize JSON with nested objects', () {
        const body = '{"id": "456", "type": "order.placed"}';

        final event = WebhookDeserializers.json(body, TestEvent.fromJson);

        expect(event.id, equals('456'));
        expect(event.type, equals('order.placed'));
      });

      test('should throw FormatException for invalid JSON', () {
        const body = 'not valid json';

        expect(
          () => WebhookDeserializers.json(body, TestEvent.fromJson),
          throwsFormatException,
        );
      });

      test('should throw TypeError for non-map JSON', () {
        const body = '["array", "not", "map"]';

        expect(
          () => WebhookDeserializers.json(body, TestEvent.fromJson),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('form', () {
      test('should deserialize form-encoded payload', () {
        const body = 'command=/hello&text=world';

        final data = WebhookDeserializers.form(body, TestFormData.fromForm);

        expect(data.command, equals('/hello'));
        expect(data.text, equals('world'));
      });

      test('should handle URL-encoded values', () {
        const body = 'command=/test&text=hello%20world';

        final data = WebhookDeserializers.form(body, TestFormData.fromForm);

        expect(data.command, equals('/test'));
        expect(data.text, equals('hello world'));
      });

      test('should handle empty values', () {
        const body = 'command=/empty&text=';

        final data = WebhookDeserializers.form(body, TestFormData.fromForm);

        expect(data.command, equals('/empty'));
        expect(data.text, equals(''));
      });

      test('should handle missing optional fields', () {
        const body = 'command=/test';

        final data = WebhookDeserializers.form(body, TestFormData.fromForm);

        expect(data.command, equals('/test'));
        expect(data.text, equals(''));
      });
    });
  });
}
