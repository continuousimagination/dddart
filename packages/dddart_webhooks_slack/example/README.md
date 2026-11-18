# dddart_webhooks_slack examples

Set `SLACK_SIGNING_SECRET` in the server environment. Configure Slack with a publicly reachable HTTPS callback ending in `/slack/commands`, or start with the [compile-only Slack quickstart](../../../docs/quickstarts/slack_server/README.md).

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_webhooks_slack/example
dart pub get
dart run slash_command_example.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [interactive_message_example.dart](interactive_message_example.dart) | Configured integration | Handle interactive Slack messages at `/slack/interactive`. |
| [slash_command_example.dart](slash_command_example.dart) | Configured integration | Verify a slash command and send a response at `/slack/commands`. |
