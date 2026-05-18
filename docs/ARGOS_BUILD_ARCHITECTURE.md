# ARGOS Full Build Architecture for Codex CLI

## Mission

ARGOS is a local-first operator memory substrate.

The MVP loop:

```txt
Codex starts with canon-aware context.
Codex ends with outcome provenance.
ARGOS remembers what happened.
Operator approves what becomes canon.
```

## Non-negotiables

```txt
01 local-first before cloud
02 Memory MVP before intelligence
03 append-only before mutation
04 provenance before adaptation
05 approvals before autonomy
06 vertical slices before grand substrate
07 boring stack before clever stack
08 CLI + HTML before heavy UI
09 JSON/YAML/JSONL/Markdown for AI-readable surfaces
10 one app, one DB, one supervision tree
```

## System shape

```txt
ARGOS
├── Phoenix app
├── Postgres
├── Oban
├── pgvector later
├── LiveView dashboard
├── local CLI
├── Codex hooks
├── JSON/Markdown context packs
└── external execution arms
```

Do not build microservices.
Do not build full autonomy.
Do not build Intelligence/R&D until Memory MVP is alive.

## Repo layout

```txt
argos/
├── AGENTS.md
├── README.md
├── mix.exs
├── config/
├── priv/
│   ├── repo/migrations/
│   ├── seed_data/
│   └── static_pwas/
├── lib/
│   ├── argos/
│   │   ├── application.ex
│   │   ├── repo.ex
│   │   ├── kernel/
│   │   │   ├── hashing.ex
│   │   │   ├── provenance.ex
│   │   │   └── policy.ex
│   │   ├── memory/
│   │   │   ├── event.ex
│   │   │   ├── events.ex
│   │   │   ├── canon.ex
│   │   │   └── canons.ex
│   │   ├── approvals/
│   │   ├── context/
│   │   ├── arms/
│   │   ├── codex/
│   │   └── jobs/
│   └── argos_web/
│       ├── controllers/
│       ├── live/
│       ├── router.ex
│       └── endpoint.ex
├── test/
├── scripts/
│   ├── argos
│   ├── codex-start.sh
│   └── codex-end.sh
└── .argos/
    ├── context-pack.md
    ├── context-pack.json
    ├── outcome.json
    └── session.json
```

## OTP tree

```txt
Argos.Application
└── Argos.Supervisor
    ├── Argos.Repo
    ├── Phoenix.PubSub
    ├── ArgosWeb.Endpoint
    ├── Oban
    ├── Argos.Kernel.PolicyCache
    ├── Argos.Memory.Supervisor
    ├── Argos.Approvals.Supervisor
    ├── Argos.Context.Supervisor
    └── Argos.Arms.Supervisor
```

Rule:

- GenServers coordinate.
- Oban does durable work.
- Postgres is source of truth.

## Core modules

```txt
Argos.Kernel.Hashing
- canonical JSON encoding
- SHA256 hash
- hash-chain validation

Argos.Kernel.Provenance
- provenance structs
- pack lineage
- outcome lineage

Argos.Kernel.Policy
- authority checks
- risk levels
- approval requirement

Argos.Memory.Events
- append event
- list events
- validate chain

Argos.Memory.Canons
- draft canon
- commit approved canon
- diff versions

Argos.Approvals
- create approval
- approve/reject
- enforce operator-only commits

Argos.Context.Packs
- compile context pack
- persist pack
- render Markdown/JSON

Argos.Arms
- register arm
- start session
- close session
- attach outcome

Argos.Codex
- build Codex session payload
- parse git/test outcome
- post outcome event
```

## Database MVP

```txt
events
canons
approvals
context_packs
arms
arm_sessions
outcomes
artifacts
operator_states
```

### events

```txt
id binary_id
kind string
canon string
source string
payload map
prev_hash string
hash string
author string
occurred_at utc_datetime_usec
inserted_at utc_datetime_usec
```

Indexes:

```txt
unique(hash)
(canon, occurred_at)
(kind)
(source)
```

### canons

```txt
id binary_id
name string
version integer
state map
ancestor_hash string
hash string
status string # draft | approved | superseded
approved_by string
approved_at utc_datetime_usec
```

Indexes:

```txt
unique(name, version)
unique(hash)
(name, status)
```

### approvals

```txt
id binary_id
subject_type string
subject_id binary_id
action string
risk_level string # low | medium | high | critical
status string # pending | approved | rejected | expired
proposal map
reason text
decided_by string
decided_at utc_datetime_usec
```

### context_packs

```txt
id binary_id
hash string
task text
canon string
canon_versions map
operator_state_id binary_id
retrieval_policy map
skill_refs map
payload map
markdown text
compiled_at utc_datetime_usec
```

### arms

```txt
id binary_id
slug string
name string
authority string
config map
inserted_at utc_datetime_usec
updated_at utc_datetime_usec
```

### arm_sessions

```txt
id binary_id
arm string
project string
task text
context_pack_id binary_id
started_at utc_datetime_usec
ended_at utc_datetime_usec
status string
```

### outcomes

```txt
id binary_id
arm_session_id binary_id
context_pack_id binary_id
event_id binary_id
result string # success | partial | fail | blocked
summary text
metrics map
artifacts map
captured_at utc_datetime_usec
```

## API MVP

```txt
POST /api/capture
GET  /api/events
GET  /api/canon/:name
POST /api/canon/:name/draft
POST /api/approvals/:id/approve
POST /api/approvals/:id/reject
GET  /api/approvals
POST /api/context-pack
GET  /api/context-pack/:hash
POST /api/arms/session/start
POST /api/arms/session/end
POST /api/outcomes
GET  /api/health
```

## Codex CLI contract

Local files:

```txt
.argos/context-pack.md
.argos/context-pack.json
.argos/session.json
.argos/outcome.json
```

Start flow:

```bash
argos codex start --project irftek --canon irftek --task "implement capture endpoint"
```

Does:

```txt
1. POST /api/context-pack
2. write .argos/context-pack.md
3. write .argos/context-pack.json
4. start arm_session
5. write .argos/session.json
6. launch codex with context
```

End flow:

```bash
argos codex end
```

Does:

```txt
1. collect git diff summary
2. collect changed files
3. run tests if configured
4. write .argos/outcome.json
5. POST /api/arms/session/end
6. POST /api/outcomes
7. POST /api/capture kind=codex_outcome
```

## Authority model

```txt
observe_only
suggest_only
write_local
write_repo
execute_low_risk
execute_high_risk
financial_action
```

Defaults:

```txt
codex_cli: write_repo
manual: execute_low_risk
browser_agent: suggest_only
trading_bot: suggest_only
pip: observe_only
```

Hard rule:

```txt
financial_action always requires approval
canon_commit always requires approval
external_publish always requires approval
```

## Context pack format

```md
---
argos_context_pack: v1
hash: sha256...
canon: irftek
canon_version: 3
task: "implement capture endpoint"
compiled_at: 2026-05-17T00:00:00Z
operator_state_id: null
retrieval_policy: memory_mvp_v1
---

# Task

Implement capture endpoint.

# Active Canon

...

# Relevant Events

...

# Decisions

...

# Constraints

- immutable canon
- append-only events
- approval required for canon commit
- tests required

# Expected Outcome

- code changed
- tests pass
- outcome posted
```

## Event payload kinds

```txt
manual_note
voice_note
codex_session_started
codex_session_ended
codex_outcome
canon_draft
canon_commit
approval_created
approval_decided
context_pack_compiled
decision_recorded
artifact_attached
```

Use explicit `kind`.
No vague `misc`.

## Local CLI commands

```bash
argos health
argos capture "text"
argos canon show operator
argos canon draft operator ./canon.yaml
argos approvals list
argos approvals approve <id>
argos pack --canon irftek --task "..."
argos codex start --project irftek --task "..."
argos codex end
```

Implementation:

- shell wrapper first
- Elixir escript later only if needed

## LiveView dashboard

```txt
/
├── system health
├── event count
├── latest events
├── active canon versions
├── pending approvals
├── recent context packs
├── active arm sessions
└── failed jobs
```

Phone-first.
No heavy UI.

## Test contract

Every Codex task must add tests.

```txt
schema test
migration test
context test
controller test
job test if Oban used
LiveView smoke test if UI touched
```

Critical tests:

```txt
event hash is deterministic
event chain rejects wrong prev_hash
canon version cannot mutate
approval required for canon commit
context pack includes provenance
codex outcome links to session and pack
```

## Security baseline

```txt
local-only default
Tailscale optional
API token required
rate limit capture endpoint
no public write endpoints without token
CORS locked down
secrets in env
no API keys in event payload
artifact size limits
quarantine malformed events
```

## Oban queues

```txt
default
ingest
canon
context
outcome
index
```

Jobs:

```txt
NormalizeEventJob
HashEventJob
CanonDraftJob
ContextPackCompileJob
OutcomeScoreJob
DoctrineIndexJob
```

Rule:

- endpoint validates and enqueues when durable work is needed
- job performs durable work
- simple MVP paths may write synchronously if tested

## Build phases

### Phase 0 — boot

Goal: Phoenix app runs locally.

Build:

- Phoenix LiveView app
- Postgres repo
- Oban installed
- health endpoint
- home dashboard placeholder
- AGENTS.md

Done when:

- `mix test` passes
- `/api/health` returns ok

### Phase 1 — event chain

Goal: ARGOS remembers.

Build:

- events migration
- Event schema
- Hashing module
- append_event/1
- chain validation
- POST /api/capture

Done when:

- event hash deterministic
- prev_hash links per canon
- malformed payload rejected

### Phase 2 — canon commits

Goal: immutable canon versions.

Build:

- canons table
- draft canon
- approval-gated commit
- canon diff
- GET /api/canon/:name

Done when:

- old canon cannot mutate
- version increments
- approval required

### Phase 3 — approval queue

Goal: operator authority.

Build:

- approvals table
- approval context
- LiveView approval queue
- approve/reject endpoints

Done when:

- canon draft creates approval
- approve commits canon
- reject does not commit

### Phase 4 — context packs

Goal: Codex gets useful memory.

Build:

- context_packs table
- pack compiler
- Markdown renderer
- JSON renderer
- POST /api/context-pack

Pack contains:

- task
- canon excerpt
- recent events
- active decisions
- operator state if present
- provenance block

### Phase 5 — Codex arm

Goal: closed loop with Codex CLI.

Build:

- arms table
- arm_sessions table
- scripts/argos
- scripts/codex-start.sh
- scripts/codex-end.sh
- outcome capture

Done when:

- start creates session
- end posts diff/test summary
- outcome links to context_pack

### Phase 6 — retrieval

Goal: better context packs.

Build:

- doctrine_chunks
- Postgres full-text search
- pgvector optional
- retrieval policy map

Do not overbuild:

- start with full-text
- add embeddings only after real docs exist

### Phase 7 — adaptive stub

Goal: score outcomes without autonomy.

Build:

- scoring rules table or map
- score outcome
- attach score to pack/skill/policy
- dashboard stats

No automatic policy updates yet.

### Phase 8 — intelligence stub

Goal: proposals, not actions.

Build:

- proposal_queue
- contradiction detector v0
- gap detector v0
- proposals require approval

No autonomous canon edits.

## Do not build yet

```txt
multi-operator
Pip sync
trading execution
full R&D loop
autonomous experiments
hot-code loading
microservices
complex role-based auth
object store
semantic graph
agent swarm
```

These are later.
Building them now creates substrate overhang.
