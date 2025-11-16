import 'package:dddart_webhooks_slack/dddart_webhooks_slack.dart';
import 'package:test/test.dart';

void main() {
  group('SlackSlashCommand', () {
    test('should deserialize from form data with all fields', () {
      // Arrange
      final form = {
        'command': '/weather',
        'text': 'San Francisco',
        'user_id': 'U123456',
        'user_name': 'john',
        'team_id': 'T123456',
        'channel_id': 'C123456',
        'response_url': 'https://hooks.slack.com/commands/123/456',
        'trigger_id': '123.456.abc',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.command, equals('/weather'));
      expect(command.text, equals('San Francisco'));
      expect(command.userId, equals('U123456'));
      expect(command.userName, equals('john'));
      expect(command.teamId, equals('T123456'));
      expect(command.channelId, equals('C123456'));
      expect(
        command.responseUrl,
        equals('https://hooks.slack.com/commands/123/456'),
      );
      expect(command.triggerId, equals('123.456.abc'));
    });

    test('should deserialize from form data without optional trigger_id', () {
      // Arrange
      final form = {
        'command': '/help',
        'text': '',
        'user_id': 'U789012',
        'user_name': 'jane',
        'team_id': 'T789012',
        'channel_id': 'C789012',
        'response_url': 'https://hooks.slack.com/commands/789/012',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.command, equals('/help'));
      expect(command.text, equals(''));
      expect(command.userId, equals('U789012'));
      expect(command.userName, equals('jane'));
      expect(command.teamId, equals('T789012'));
      expect(command.channelId, equals('C789012'));
      expect(
        command.responseUrl,
        equals('https://hooks.slack.com/commands/789/012'),
      );
      expect(command.triggerId, isNull);
    });

    test('should handle empty text field', () {
      // Arrange
      final form = {
        'command': '/status',
        'user_id': 'U111',
        'user_name': 'bob',
        'team_id': 'T111',
        'channel_id': 'C111',
        'response_url': 'https://hooks.slack.com/commands/111/222',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.command, equals('/status'));
      expect(command.text, equals(''));
    });

    test('should handle text with spaces and special characters', () {
      // Arrange
      final form = {
        'command': '/echo',
        'text': 'Hello, World! @user #channel',
        'user_id': 'U222',
        'user_name': 'alice',
        'team_id': 'T222',
        'channel_id': 'C222',
        'response_url': 'https://hooks.slack.com/commands/222/333',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.text, equals('Hello, World! @user #channel'));
    });

    test('should create command with constructor', () {
      // Act
      const command = SlackSlashCommand(
        command: '/test',
        text: 'test text',
        userId: 'U333',
        userName: 'testuser',
        teamId: 'T333',
        channelId: 'C333',
        responseUrl: 'https://hooks.slack.com/test',
        triggerId: 'trigger123',
      );

      // Assert
      expect(command.command, equals('/test'));
      expect(command.text, equals('test text'));
      expect(command.userId, equals('U333'));
      expect(command.userName, equals('testuser'));
      expect(command.teamId, equals('T333'));
      expect(command.channelId, equals('C333'));
      expect(command.responseUrl, equals('https://hooks.slack.com/test'));
      expect(command.triggerId, equals('trigger123'));
    });

    test('should support equality comparison', () {
      // Arrange
      const command1 = SlackSlashCommand(
        command: '/test',
        text: 'hello',
        userId: 'U444',
        userName: 'user1',
        teamId: 'T444',
        channelId: 'C444',
        responseUrl: 'https://hooks.slack.com/test',
      );

      const command2 = SlackSlashCommand(
        command: '/test',
        text: 'hello',
        userId: 'U444',
        userName: 'user1',
        teamId: 'T444',
        channelId: 'C444',
        responseUrl: 'https://hooks.slack.com/test',
      );

      const command3 = SlackSlashCommand(
        command: '/different',
        text: 'hello',
        userId: 'U444',
        userName: 'user1',
        teamId: 'T444',
        channelId: 'C444',
        responseUrl: 'https://hooks.slack.com/test',
      );

      // Assert
      expect(command1, equals(command2));
      expect(command1, isNot(equals(command3)));
    });

    test('should include all properties in props getter', () {
      // Arrange
      const command = SlackSlashCommand(
        command: '/props',
        text: 'test',
        userId: 'U555',
        userName: 'propsuser',
        teamId: 'T555',
        channelId: 'C555',
        responseUrl: 'https://hooks.slack.com/props',
        triggerId: 'trigger555',
      );

      // Act
      final props = command.props;

      // Assert
      expect(props, hasLength(8));
      expect(props, contains('/props'));
      expect(props, contains('test'));
      expect(props, contains('U555'));
      expect(props, contains('propsuser'));
      expect(props, contains('T555'));
      expect(props, contains('C555'));
      expect(props, contains('https://hooks.slack.com/props'));
      expect(props, contains('trigger555'));
    });

    test('should handle real Slack slash command payload', () {
      // Arrange - Real example from Slack documentation
      final form = {
        'token': 'gIkuvaNzQIHg97ATvDxqgjtO',
        'team_id': 'T0001',
        'team_domain': 'example',
        'enterprise_id': 'E0001',
        'enterprise_name': 'Globular%20Construct%20Inc',
        'channel_id': 'C2147483705',
        'channel_name': 'test',
        'user_id': 'U2147483697',
        'user_name': 'Steve',
        'command': '/weather',
        'text': '94070',
        'response_url': 'https://hooks.slack.com/commands/1234/5678',
        'trigger_id': '13345224609.738474920.8088930838d88f008e0',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.command, equals('/weather'));
      expect(command.text, equals('94070'));
      expect(command.userId, equals('U2147483697'));
      expect(command.userName, equals('Steve'));
      expect(command.teamId, equals('T0001'));
      expect(command.channelId, equals('C2147483705'));
      expect(
        command.responseUrl,
        equals('https://hooks.slack.com/commands/1234/5678'),
      );
      expect(
        command.triggerId,
        equals('13345224609.738474920.8088930838d88f008e0'),
      );
    });

    test('should handle command with URL-encoded text', () {
      // Arrange
      final form = {
        'command': '/search',
        'text': 'hello+world',
        'user_id': 'U666',
        'user_name': 'searcher',
        'team_id': 'T666',
        'channel_id': 'C666',
        'response_url': 'https://hooks.slack.com/search',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.text, equals('hello+world'));
    });

    test('should handle multiple word usernames', () {
      // Arrange
      final form = {
        'command': '/info',
        'text': 'details',
        'user_id': 'U777',
        'user_name': 'john.doe',
        'team_id': 'T777',
        'channel_id': 'C777',
        'response_url': 'https://hooks.slack.com/info',
      };

      // Act
      final command = SlackSlashCommand.fromForm(form);

      // Assert
      expect(command.userName, equals('john.doe'));
    });
  });
}
