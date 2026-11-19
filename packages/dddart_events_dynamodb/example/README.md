# dddart_events_dynamodb examples

Start [DynamoDB Local](../../../docs/quickstarts/dynamodb/README.md#start-dynamodb-local). The program creates a temporary table and deletes it when finished.

From the root of a DDDart checkout, run the following with the [example pubspec](pubspec.yaml).

```sh
cd packages/dddart_events_dynamodb/example
dart pub get
dart run history.dart
```

| Program | How it runs | What it shows |
| --- | --- | --- |
| [history.dart](history.dart) | Local database | Recover an event after a checkpoint and rotate its channel. |
