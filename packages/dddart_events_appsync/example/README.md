# dddart_events_appsync examples

Try an authorizer and subscription handler locally. The [deployment guide](../DEPLOY.md) covers the Lambda entrypoint and how to exercise an existing AWS deployment.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_events_appsync/example
dart pub get
dart run native_invocation.dart
```

## Choose a program

| Program | How it runs | What it shows |
| --- | --- | --- |
| [native_invocation.dart](native_invocation.dart) | Local run | Authorize a local caller and subscribe to its channel. |
| [lambda.dart](lambda.dart) | Configured integration | Run the event handlers inside a deployed Lambda runtime. |
| [aws_smoke.dart](aws_smoke.dart) | Configured integration | Exercise publication and subscription against your deployed AWS resources. |
