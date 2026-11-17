---
title: Build an HTTP API
description: Serve a Dart repository over HTTP and choose public or protected access for each operation.
section: Connect the pieces
order: 20
---

Expose a repository with a `CrudResource<T, I, TClaims>` and a serializer on
the server. The generated REST repository implements the same typed CRUD
contract on the client. Use concrete identities and the same canonical
identity codec on both sides.

## Run a public server and client

The [HTTP quickstart](https://github.com/continuousimagination/dddart/blob/main/docs/quickstarts/rest/README.md)
starts a local server, saves and reads a note through a generated client, and
closes both. Follow it to get the exact files and commands. It needs no login
or token. If an existing host owns the listener, compose
`HttpServer.buildHandler()` into that host.

## Public and protected operations

A resource can be public. Supplying an authentication handler requires a verified
caller by default unless an operation has its own policy. For example, allow
anonymous reads of a leaderboard and require permission to write scores. Run
the [public leaderboard example](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/example/README.md)
for that pattern and for private records with scoped collection reads.

Define a handler for each collection query your application supports. Apply the
authorized scope to both rows and total count before paging. A client filter
can narrow the authorized set. It cannot make more rows visible. For custom
mutation policies, use authoritative snapshots and a repository that can bind
the authorization decision to the revision it checks. See the
[REST policy guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest/README.md#optional-access-policies)
for the policy contexts and failure behavior.

## Prevent lost updates

Use versioned reads and explicit conditional calls when one writer must
detect another's change. A strong ETag carries the stored revision. A stale
condition needs a reload and an application decision about whether to reapply
the update. Ordinary `save` uses unconditional PUT where the resource allows
it. The [conditional writes guide](https://github.com/continuousimagination/dddart/blob/main/docs/CONDITIONAL_WRITES.md)
describes the required storage capability and how to handle an unknown result.

## Authentication providers and platforms

On the server, choose a credential verifier and resource policies. On the
client, supply a token provider only for calls that need authentication. The
[REST client guide](https://github.com/continuousimagination/dddart/blob/main/packages/dddart_rest_client/README.md)
describes device flow, Cognito/OIDC callbacks, and credential storage. Supply
storage and callback handling appropriate to your browser or mobile
application.
