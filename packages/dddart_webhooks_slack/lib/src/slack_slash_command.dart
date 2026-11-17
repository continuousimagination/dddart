import 'package:dddart/dddart.dart';

/// Represents a Slack slash command webhook payload.
///
/// Slack sends slash command data as form-encoded POST requests.
/// Use the [SlackSlashCommand.fromForm] factory constructor to deserialize
/// the webhook payload.
///
/// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks_slack/README.md).
class SlackSlashCommand extends Value {
  /// Creates a Slack slash command.
  const SlackSlashCommand({
    required this.command,
    required this.text,
    required this.userId,
    required this.teamId,
    required this.channelId,
    required this.responseUrl,
    this.userName,
    this.triggerId,
  });

  /// Creates a [SlackSlashCommand] from form-encoded data.
  ///
  /// Slack sends slash commands as application/x-www-form-urlencoded POST
  /// requests. This factory constructor parses the form data into a
  /// strongly-typed command object.
  ///
  /// See the [complete examples and setup](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_webhooks_slack/README.md).
  factory SlackSlashCommand.fromForm(Map<String, String> form) {
    return SlackSlashCommand(
      command: form['command']!,
      text: form['text'] ?? '',
      userId: form['user_id']!,
      userName: form['user_name'],
      teamId: form['team_id']!,
      channelId: form['channel_id']!,
      responseUrl: form['response_url']!,
      triggerId: form['trigger_id'],
    );
  }

  /// The command that was typed, including the leading slash (e.g., '/weather').
  final String command;

  /// The text that was typed after the command (e.g., 'San Francisco').
  final String text;

  /// The ID of the user who triggered the command.
  final String userId;

  /// The legacy username of the user who triggered the command.
  ///
  /// Slack may omit this deprecated field. Use [userId] as the canonical user
  /// identity.
  final String? userName;

  /// The ID of the workspace/team where the command was triggered.
  final String teamId;

  /// The ID of the channel where the command was triggered.
  final String channelId;

  /// A temporary webhook URL for sending delayed responses.
  ///
  /// You can POST to this URL within 30 minutes of receiving the command
  /// to send additional messages to the user.
  final String responseUrl;

  /// A temporary ID that can be used to open modals.
  ///
  /// This is optional and may be null for some slash commands.
  final String? triggerId;

  @override
  List<Object?> get props => [
        command,
        text,
        userId,
        userName,
        teamId,
        channelId,
        responseUrl,
        triggerId,
      ];
}
