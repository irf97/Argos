# ARGOS Tutorial

This tutorial sets up ARGOS as a local desktop memory hub that multiple agents can use at the same time.

The intended shape is:

```txt
Claude Desktop -> stdio bridge -> ARGOS MCP -> Phoenix -> local Postgres
OpenAI/GPT app -> HTTP MCP ----------------^
local agents  -> HTTP API or HTTP MCP -----^
browser       -> http://127.0.0.1:4020 ----^
```

Run one ARGOS process on the desktop. Do not let every agent start its own memory server.

## 1. Prerequisites

Install these before running ARGOS:

- Elixir and Erlang/OTP.
- PostgreSQL running locally.
- PowerShell.
- Python 3 if you want Claude Desktop to use the stdio bridge.

The default development database is:

```txt
database: argos_dev
host: localhost
user: postgres
```

## 2. Clone and Set Up

From the directory where you keep local AI projects:

```powershell
git clone <your-argos-repo-url> argos-codex-cli-pack
cd argos-codex-cli-pack
mix setup
```

If you already have this folder locally, just enter it:

```powershell
cd C:\AI\Projects\Argos\wei\argos-codex-cli-pack
mix ecto.migrate
```

## 3. Start ARGOS on Port 4020

For the desktop hub, use the scripts:

```powershell
scripts\start-argos.ps1
scripts\status-argos.ps1
```

Expected status:

```json
{
  "base_url": "http://127.0.0.1:4020",
  "listening": true,
  "health_ok": true,
  "mcp_tool_count": 9
}
```

Manual development start also works:

```powershell
$env:PORT = "4020"
mix phx.server
```

Then open:

```txt
http://127.0.0.1:4020
```

Use `127.0.0.1`, not `localhost`, so every client resolves the same loopback address.

## 4. Install the Always-On Desktop Hub

Install the startup launcher:

```powershell
scripts\install-argos-desktop.ps1
```

This creates:

```txt
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ArgosDesktopHub.cmd
```

It also sets user environment variables:

```txt
ARGOS_URL=http://127.0.0.1:4020
ARGOS_MCP_URL=http://127.0.0.1:4020/mcp
ARGOS_HOME=<repo path>
```

Open a new terminal after installing so the variables are inherited.

To stop the hub:

```powershell
scripts\stop-argos.ps1
```

To remove startup wiring:

```powershell
scripts\uninstall-argos-desktop.ps1
```

## 5. Verify the HTTP API

Health:

```powershell
Invoke-RestMethod http://127.0.0.1:4020/api/health
```

Capture one memory event:

```powershell
$body = @{
  kind = "manual_note"
  canon = "operator"
  source = "tutorial"
  payload = @{ text = "ARGOS tutorial capture works" }
  author = "operator"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:4020/api/capture `
  -ContentType "application/json" `
  -Body $body
```

List recent events:

```powershell
Invoke-RestMethod http://127.0.0.1:4020/api/events
```

## 6. Verify MCP Directly

List MCP tools:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:4020/mcp `
  -ContentType "application/json" `
  -Body '{"jsonrpc":"2.0","id":"tools","method":"tools/list"}'
```

Write through MCP:

```powershell
$body = @{
  jsonrpc = "2.0"
  id = "capture"
  method = "tools/call"
  params = @{
    name = "argos_capture"
    arguments = @{
      kind = "manual_note"
      canon_id = "operator"
      content = "MCP capture works"
    }
  }
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:4020/mcp `
  -ContentType "application/json" `
  -Body $body
```

Search through MCP:

```powershell
$body = @{
  jsonrpc = "2.0"
  id = "search"
  method = "tools/call"
  params = @{
    name = "search"
    arguments = @{ query = "MCP capture works" }
  }
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:4020/mcp `
  -ContentType "application/json" `
  -Body $body
```

## 7. Connect Claude Desktop

Claude Desktop uses stdio MCP, so point it at the included bridge.

Edit:

```txt
%APPDATA%\Claude\claude_desktop_config.json
```

Merge this under `mcpServers` without deleting existing servers:

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

Restart Claude Desktop and check that the `argos` tools are visible.

Useful Claude prompt:

```txt
Use ARGOS as shared local memory. First call argos_state. If I ask you to remember something, call argos_capture with kind "manual_note", canon_id "operator", and a concise content field. Before answering questions about stored memory, use argos_search.
```

## 8. Connect OpenAI/GPT Clients

Local OpenAI-compatible clients that support HTTP MCP should use:

```txt
http://127.0.0.1:4020/mcp
```

For a read-only setup, allow only:

```txt
search
fetch
```

For write-capable local development, also allow:

```txt
argos_capture
argos_pack
argos_propose
argos_state
```

ChatGPT web cannot reach your desktop `127.0.0.1`. For ChatGPT web, expose ARGOS through a public HTTPS tunnel only when needed, then start ARGOS with:

```powershell
$env:ARGOS_PUBLIC_URL = "https://your-public-url.example"
scripts\start-argos.ps1
```

Keep public access behind authentication or a trusted private network.

## 9. Use ARGOS From Multiple Agents

Every local agent should target the same address:

```txt
ARGOS_MCP_URL=http://127.0.0.1:4020/mcp
ARGOS_URL=http://127.0.0.1:4020
```

Agents should not connect directly to Postgres. Use HTTP API or MCP so ARGOS owns validation, event hashing, and per-canon chain updates.

Safe defaults:

- Read-only agents get `search` and `fetch`.
- Trusted local coding agents can get `argos_capture`.
- Human-reviewed planning agents can get `argos_propose`.
- Avoid giving broad write tools to remote clients.

## 10. Troubleshooting

Check status:

```powershell
scripts\status-argos.ps1
```

If port `4020` is busy:

```powershell
scripts\stop-argos.ps1
scripts\start-argos.ps1
```

Logs:

```txt
.argos/argos-4020.out.log
.argos/argos-4020.err.log
.argos/argos-mcp-stdio.log
```

If Claude shows no tools:

- Restart Claude Desktop.
- Confirm ARGOS is live with `scripts\status-argos.ps1`.
- Confirm `claude_desktop_config.json` still contains every existing MCP server plus `argos`.
- Check `.argos/argos-mcp-stdio.log`.

If MCP calls hang:

- Restart ARGOS.
- Check Postgres is running.
- Run `mix test` to verify the write path.

## 11. Publish to GitHub

If this folder is not a git checkout yet, initialize it after reviewing local-only files:

```powershell
git init
git add .
git commit -m "Add Argos desktop hub tutorial"
git branch -M main
git remote add origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

If the remote already exists:

```powershell
git remote -v
git add README.md START_HERE.md docs scripts lib test config priv mix.exs mix.lock .gitignore AGENTS.md
git commit -m "Document Argos desktop hub setup"
git push
```
