---
title: Layer configuration
description: Read defaults from YAML, override selected settings, and validate the result before startup.
section: Connect the pieces
order: 40
---

Read configuration where you construct your services. Pass the resulting
values into a repository or HTTP client so the domain does not read process
environment variables or files.

## Layer environment variables over YAML

Work through the [configuration quickstart](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/configuration/README.md).
It reads a YAML file and lets an environment value override its database
host. Put the environment provider ahead of the YAML provider in the list:
providers are ordered from highest to lowest priority.

With prefix `BOOKING`, `BOOKING_DATABASE_HOST` addresses `database.host`.
Use a double underscore for an underscore inside a key. Environment values
are strings; use YAML or a structural provider when you need maps and lists.
Maps merge by key, lists replace whole lists, and an explicit null masks
a lower-priority value.

## Validate before starting services

Use typed getters for settings and `ConfigRequirement` to validate the set a
service needs. For instance, require an integer port and reject values outside
the application's allowed range. Validation reports paths and types without
including secret values. Follow the
[validation example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_config/example/validation_example.dart)
for the complete declarations.

Call `reload()` when you want providers to refresh. Apply the new values to
running services yourself. A config reload does not reopen a database connection.

## Supply a custom provider

The supplied environment and file providers use native IO. For a browser or
a source such as an embedded map, supply your own `ConfigProvider`. The
[custom provider program](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/configuration/bin/provider.dart)
shows how an empty-path lookup exposes the entire root for merging. See the
[package guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_config/README.md)
for lookup rules, type conversion, and reload behavior.
