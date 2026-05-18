# ARGOS Build Doctrine

Build ARGOS as a local-first operator memory substrate.

## Load-bearing rules

- One Phoenix app.
- One Postgres database.
- One supervision tree.
- Binary IDs everywhere.
- No microservices.
- No autonomous execution.
- No autonomous trading.
- No intelligence loop until Memory MVP passes tests.
- No R&D loop until context-pack provenance works.
- Events are append-only.
- Event hashes are deterministic.
- Events are hash-linked per canon.
- Canon versions are immutable.
- Canon commits require operator approval unless the latest canon version explicitly declares a bounded autonomy policy that allows the proposal.
- Autonomous canon mutation is bounded only; it must create an audit row and keep a 24h rollback window.
- Context packs require provenance.
- Codex CLI is an external execution arm, not the owner of ARGOS.
- Run `mix format` and `mix test` before finishing.

## Design principles

- Local-first before cloud.
- Semantics before raw data.
- AI-readable by default.
- Minimal primitives before complexity.
- Simple UI over heavy UI.
- Runtime transparency.
- Graceful degradation.
- Security as immune system.
- No bloat by default.

## Implementation order

1. migrations
2. schemas
3. context modules
4. tests
5. controllers
6. LiveView
7. CLI scripts
8. docs update

## Stop conditions

Stop and explain if a requested change would add:

- a second app
- a second database
- cloud dependency
- autonomous execution
- unbounded autonomous canon mutation
- intelligence/R&D before Memory MVP
- trading execution
- multi-operator complexity
- hot-code loading
- agent swarm behavior
