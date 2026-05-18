# Start Here

If you are installing ARGOS for desktop use, start with `docs/TUTORIAL.md`.

## Best use

Use three layers:

1. `AGENTS.md` for standing doctrine.
2. `docs/ARGOS_BUILD_ARCHITECTURE.md` for full build map.
3. One prompt from `prompts/` per Codex run.

Do not paste the entire architecture into Codex every time.
Keep Codex on one vertical slice per run.

## Install/use pattern

From your target repo root:

```bash
cp /path/to/argos-codex-cli-pack/AGENTS.md .
mkdir -p docs prompts scripts .argos
cp /path/to/argos-codex-cli-pack/docs/ARGOS_BUILD_ARCHITECTURE.md docs/
cp /path/to/argos-codex-cli-pack/prompts/*.txt prompts/
cp /path/to/argos-codex-cli-pack/scripts/* scripts/
chmod +x scripts/*
```

Then:

```bash
codex
```

Paste:

```txt
Read AGENTS.md and docs/ARGOS_BUILD_ARCHITECTURE.md.
Then execute prompts/00_PHASE_0_1_MEMORY_MVP.txt exactly.
```

## Phase order

```txt
00 Phase 0/1: Boot + event chain
01 Phase 2/3: Canons + approvals
02 Phase 4/5: Context packs + Codex arm
03 Phase 6: Retrieval
04 Phase 7: Adaptive scoring stub
05 Phase 8: Intelligence proposal stub
```

## Hard stop

If Phase 0/1 does not pass tests, do not continue.
