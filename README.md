# Argos

ARGOS is a local-first operator memory hub for AI agents. It runs as one Phoenix app backed by local Postgres and exposes both HTTP APIs and MCP tools.

The default desktop address is:

```txt
http://127.0.0.1:4020
```

## Start

```powershell
mix setup
scripts\start-argos.ps1
scripts\status-argos.ps1
```

Open:

```txt
http://127.0.0.1:4020
```

Manual development start:

```powershell
$env:PORT = "4020"
mix phx.server
```

## Tutorial

Start here:

- [ARGOS Tutorial](docs/TUTORIAL.md)
- [Operational Spec HTML](docs/ARGOS_SPEC.html)
- [Desktop Hub](docs/DESKTOP_HUB.md)
- [Claude MCP](docs/CLAUDE_MCP.md)
- [OpenAI MCP](docs/OPENAI_MCP.md)

## MCP

HTTP MCP endpoint:

```txt
http://127.0.0.1:4020/mcp
```

Claude Desktop stdio bridge:

```txt
scripts\argos-mcp-stdio.cmd
```

## Verify

```powershell
mix test
```
