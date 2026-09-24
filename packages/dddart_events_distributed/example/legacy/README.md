# Distributed-events WIP archive

These `.skip` sources are preserved as design history only. They are not
runnable examples and make no current guarantee about event-registry generation,
HTTP client/server composition, polling, or bulk time-range semantics. Those
contracts remain deferred to EVENT-001 through EVENT-004.

The only active source in the parent example package is the independent
`CustomStoredEvent` JSON round-trip. It exercises the existing `dddart_json`
serializer behavior and does not validate any distributed-event contract.
