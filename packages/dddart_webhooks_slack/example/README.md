# dddart_webhooks_slack examples

Compile locally. To receive Slack requests, configure a Slack app, signing secret, and callback URL as described in the [package guide](../README.md). See the [package guide](../README.md) for its API.

## Run from a checkout

Resolve the workspace, then run this lane from the repository root. It uses
the [example pubspec](pubspec.yaml) for dependencies and generation.

```sh
dart pub get
dart tool/validation/validate.dart example dddart_webhooks_slack_example --mode=ci
```

## Programs

| Program | How it runs | What it shows |
| --- | --- | --- |
| [interactive_message_example.dart](interactive_message_example.dart) | Compile only | Requires Slack signing secrets, interactive requests, and a public callback URL. |
| [slash_command_example.dart](slash_command_example.dart) | Compile only | Requires Slack signing secrets, slash-command requests, and a public callback URL. |

Compile-only programs need the configuration or running server indicated above.
