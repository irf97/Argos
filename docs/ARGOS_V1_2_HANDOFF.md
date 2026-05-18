# ARGOS v1.2 Handoff

ARGOS v1.2 keeps ARGOS as one Phoenix app, one Postgres database, and one supervision tree.

## Implemented v1.2 Delta

- Bounded autonomous canonization is enabled per canon.
- New canons still default to `require_approval`.
- A canon may opt into autonomy through `autonomy_policy` on the latest canon version.
- Auto-apply checks:
  - mode is `auto_apply_bounded` or `auto_apply_open`
  - proposal kind is allowed unless mode is open
  - risk level is at or below the severity ceiling
  - daily cap is still available
  - invocation evidence and confidence meet policy thresholds
  - protected touches are absent
- Protected touches always require approval:
  - design law
  - schema changes
  - autonomy policy changes
- Every autonomous canon mutation writes an `autonomous_mutations` audit row.
- Rollback is available for 24 hours through the API and CLI.

## New Routes

```txt
GET  /api/autonomous-mutations
POST /api/autonomous-mutations/:proposal_id/rollback
```

## CLI

```bash
argos rollback <proposal_id> [reason]
```

## Still Not Implemented

- Adaptive hot-load.
- Constellation bridge.
- MCP server.
- Versioned retrieval policies table.
- Operator state vector capture.
- R&D loop.
- Aen mirror watcher.

## Verification

Last verified with:

```bash
mix format
mix test
```

Result: 68 tests, 0 failures.
