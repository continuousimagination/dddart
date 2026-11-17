# Quickstarts and snippet scope

Use the complete workflows below from an empty application directory outside this
monorepo. Each has an exact Git-only pubspec, named files, generation/analysis/run
commands, expected output and cleanup. They use code revision
`56607ac8d3913b8e896ac03f8ecff58473d62ce2` and Dart 3.13.7. Publication and minimum
SDK decisions remain under #30/#98; these are tested development instructions.

| Complete workflow | Canonical source and instructions | Additional prerequisite |
| --- | --- | --- |
| Domain model, repository and local event | [Core](quickstarts/core/README.md) | Dart VM |
| Generated JSON, config and typed identity round trips | [JSON](quickstarts/json/README.md) | build_runner (declared in pubspec) |
| SQLite repository | [SQLite](quickstarts/sqlite/README.md) | Native VM and SQLite shared library; no server |
| MySQL repository | [MySQL](quickstarts/mysql/README.md) | Disposable MySQL 8 on localhost:3307 |
| MongoDB repository | [MongoDB](quickstarts/mongodb/README.md) | Disposable MongoDB on localhost:27017 |
| DynamoDB repository | [DynamoDB Local](quickstarts/dynamodb/README.md) | Fresh disposable DynamoDB Local on localhost:8000; no AWS account |
| Public HTTP server and generated REST client repository | [HTTP](quickstarts/rest/README.md) | Native VM and ephemeral loopback port; no login/token |

The core repository example retains references; it is not durable storage. The
HTTP example is deliberately public. The separate
[public/protected example](../packages/dddart_rest/example/public_leaderboard_example.dart)
shows anonymous leaderboard reads alongside protected operations and scoped
queries. Installation never makes authentication mandatory.

## Primary documentation mapping

| Surface | Executable content or explicit classification |
| --- | --- |
| Root README | Canonical JSON manifest, model and main program; links core and this inventory |
| Website getting-started | Canonical core manifest/program |
| Website serialization | Canonical JSON manifest/model/main/config/identity programs |
| Website repositories | Canonical SQLite manifest/model/program; links complete custom query examples |
| Core/serialization/JSON package READMEs | Link core/JSON; source-backed API descriptions and links to complete examples |
| SQL/SQLite/MySQL/MongoDB/DynamoDB READMEs | Link the corresponding complete adapter workflow; SQL extension contract is in [PUBLIC_API.md](PUBLIC_API.md) |
| REST/REST client/REST repository READMEs | Link the finite anonymous server/client workflow; policy examples link the tested public/protected example |
| Main public library comments | Link the same complete workflow and API inventory instead of duplicating incomplete installation/model snippets |
| Other website and package examples | Browser, service or credential-specific context as described below; not advertised as independent console programs |

## Browser and external integrations

These examples have additional context. The repository example gate resolves/generates/analyzes the named example project
and runs finite programs or compiles long-running/configured demonstrations.
Run the commands from a clone of the same revision after `dart pub get`.

| Packages | Complete context / verification command | Honest boundary |
| --- | --- | --- |
| dddart_repository_indexeddb | [Git consumer instructions](GIT_INSTALLATION.md#core-and-indexeddb); `dart tool/validation/verify_indexeddb_git_consumer.dart 56607ac8d3913b8e896ac03f8ecff58473d62ce2` | Tool creates an outside-workspace consumer and runs native Chrome; Chrome is required. This is browser persistence, not SQLite-on-Web. The adapter requires application encode/decode callbacks |
| dddart_config | [Example files and YAML](../packages/dddart_config/example); `dart tool/validation/validate.dart example dddart_config_example --mode=ci` | Finite VM examples; file/environment providers need native IO |
| dddart_events_distributed | [HTTP polling example](../packages/dddart_events_distributed/README.md#run-an-http-only-publishwatch-example); `dart tool/validation/validate.dart example dddart_events_distributed_example --mode=ci` | Finite local HTTP publication/watch; no AppSync dependency or AWS credentials |
| dddart_events_appsync | [Native invocation example](../packages/dddart_events_appsync/example/native_invocation.dart); `dart tool/validation/validate.dart example dddart_events_appsync_example --mode=ci` | Local protocol/handler demonstration. Live AppSync endpoint/token examples require application deployment and credentials; this is not cloud deployment proof |
| dddart_events_dynamodb | [History example](../packages/dddart_events_dynamodb/example/history.dart); `dart tool/validation/validate.dart example dddart_events_dynamodb_example --mode=ci` | Requires DynamoDB Local; not a live AWS test |
| dddart_webhooks | [Example setup](../packages/dddart_webhooks/example/README.md); `dart tool/validation/validate.dart example dddart_webhooks_example --mode=ci` | Long-running server examples compile; a real sender and application verifier must be supplied |
| dddart_webhooks_slack | [Example setup](../packages/dddart_webhooks_slack/example); `dart tool/validation/validate.dart example dddart_webhooks_slack_example --mode=ci` | Compile-only integration examples; live Slack signing secrets and deployment are application-owned |

The [example inventory](../tool/validation/inventory.json) records each entrypoint,
its prerequisites, action and reason. The [validation commands](../scripts/README.md)
describe local versus required CI service lanes. A compile-only or conceptual
fragment is not evidence that a cloud integration was deployed.

## Canonical inputs for documentation and release checks

`docs/quickstarts/workflows.json` lists source files, direct packages, allowed local
closure, generation requirements, service lane and exact output for every primary
workflow. `pubspec.yaml.txt` is copied to `pubspec.yaml` in a fresh application;
the suffix prevents accidental membership in the repository's Dart workspace.
Generated parts are never fixtures: build_runner must recreate them.

Published code blocks use `<!-- dddart-source: repository/relative/path -->`
markers around verbatim canonical file contents. The documentation gate (#107)
checks these inclusions and runs the workflows using isolated local package
archives. The pinned Git run verifies the instructions available before first
publication. #100 can reuse these same inputs with real hosted dependencies and
no overrides; local archive/Git runs are not pub.dev release proof. #101 owns the
release-time switch to hosted installation instructions.

## Continuous validation

The [documentation gate](../tool/documentation/README.md) now enforces this mapping.
It also checks the website's complete modeling, repository-injection and
configuration programs, and compiles the credential-dependent Slack server.
Configuration and Slack have [checked manifests](quickstarts/) alongside the seven
primary workflows; Slack is compile-only and requires real application setup to run.

Run `python3 tool/documentation/validate.py all --service-kind=none` for local
unserviced consumers and core/JSON JavaScript execution under Node. Select
`mysql`, `mongo`, or `dynamodb` for a required database lane. Plain `all` requires
all services. Every published `dddart-source` block is checked, including command
and expected-output files. All current guides, sample READMEs and library/sample Dartdoc are checked.
Unchecked Dart fences fail; new documents require explicit inventory review. See the gate documentation for
fault tests, Git mode, CI wiring and the separate hosted release responsibility.
