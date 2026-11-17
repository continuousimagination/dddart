---
title: Find an example
description: Choose a complete application or a package sample and see what you need to run it.
section: Reference
order: 20
---

## Start with a complete application

[Getting started](/dddart/docs/getting-started/) needs only Dart and the core
dependency. The
[standalone example catalog](https://github.com/continuousimagination/dddart/blob/main/docs/QUICKSTARTS.md)
has setup recipes for generated JSON, configuration, native and server
databases, public HTTP, and Slack. Each example links its own pubspec and
describes the expected result.

## Explore a package sample

Use the [package guide](/dddart/docs/packages/) to find the right adapter.
Its README links to examples and their runtime requirements. For a first
integration that needs no cloud credentials, try the
[public leaderboard](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/README.md)
or [HTTP event watch](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_events_distributed/example/README.md).

A finite sample shuts itself down. A local database sample needs the
disposable service shown in its guide. Some programs are compiled as examples
of a server or external provider integration: run those only after supplying
the named environment, service, and credentials. For development checks, see
[testing from the repository](https://github.com/continuousimagination/dddart/blob/main/scripts/README.md).

## Troubleshoot a run

| Symptom | Check |
| --- | --- |
| Pub cannot find a DDDart package | Use the linked example pubspec or follow [Git installation](https://github.com/continuousimagination/dddart/blob/main/docs/GIT_INSTALLATION.md) |
| A generated library or type is missing | Run the quickstart's build step from the package owning the model |
| A browser build includes native IO | Move the native adapter to the server or choose a [browser-compatible composition](/dddart/docs/contracts/) |
| An external sample cannot connect | Review its service, address, credentials, and provider setup |
