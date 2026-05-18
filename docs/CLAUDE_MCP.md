# Connect ARGOS to Claude with MCP

ARGOS exposes MCP tools at `POST /mcp`. Claude Desktop local MCP uses stdio, so this repo includes `scripts/argos-mcp-stdio.py` as a thin bridge from Claude stdio to the ARGOS HTTP endpoint.

## Prerequisites

Start ARGOS locally before opening Claude:

```powershell
scripts\start-argos.ps1
```

ARGOS must be reachable at `http://127.0.0.1:4020` unless `ARGOS_URL` is set to a different base URL.

## Claude Desktop on Windows

Add this server to `%APPDATA%\Claude\claude_desktop_config.json`, then restart Claude Desktop:

```json
{
  "mcpServers": {
    "argos": {
      "type": "stdio",
      "command": "C:\\AI\\Projects\\Argos\\wei\\argos-codex-cli-pack\\scripts\\argos-mcp-stdio.cmd",
      "args": [],
      "env": {
        "ARGOS_URL": "http://127.0.0.1:4020"
      }
    }
  }
}
```

If ARGOS is protected by a bearer token, add it to `env`:

```json
"ARGOS_TOKEN": "your-token"
```

In Claude Desktop, use the `+` button in the chat box and open `Connectors` to verify the `argos` server and tools are visible.

## Claude Code

Claude Code can use ARGOS directly over HTTP:

```bash
claude mcp add --transport http argos http://127.0.0.1:4020/mcp
claude mcp get argos
```

Or use the same stdio bridge:

```bash
claude mcp add --transport stdio --env ARGOS_URL=http://127.0.0.1:4020 argos -- scripts/argos-mcp-stdio.py
```

## Available Tools

- `argos_search`: search events or canons.
- `argos_pack`: compile and persist a context pack.
- `argos_capture`: append a low-stakes event to ARGOS memory.
- `argos_propose`: submit a proposal to the operator approval queue.
- `argos_state`: read recent events and the operator-state placeholder.
- `argos_crawl`: create a local crawl prompt packet.
- `argos_crawl_and_ingest`: persist normalized local AI crawl output.

## Notes

- Claude.ai remote custom connectors must reach your MCP server from Anthropic's cloud, so a local `localhost` ARGOS server will not work there without a public, authenticated URL.
- Keep ARGOS bound to localhost for local desktop use.
- The bridge writes logs to stderr only. Stdout is reserved for MCP JSON-RPC messages.
