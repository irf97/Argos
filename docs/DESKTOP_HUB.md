# ARGOS Desktop Hub

ARGOS should run as one always-on desktop memory hub.

```txt
agents -> HTTP/MCP -> Argos Phoenix -> local Postgres
Claude -> stdio bridge -> HTTP/MCP -> Argos Phoenix
human  -> browser/API -> Argos Phoenix
```

Do not let each agent spawn its own ARGOS memory process. The desktop hub is the shared source of truth.

## Fixed Local Address

```txt
ARGOS_URL=http://127.0.0.1:4020
ARGOS_MCP_URL=http://127.0.0.1:4020/mcp
```

Use `127.0.0.1`, not `localhost`, to avoid resolver ambiguity across clients.

## Data Location

ARGOS data lives in local Postgres:

```txt
database: argos_dev
host: localhost
user: postgres
```

Agents should not connect directly to Postgres. They should use the Argos HTTP API or MCP endpoint.

## Lifecycle

From the repo root:

```powershell
scripts\start-argos.ps1
scripts\status-argos.ps1
scripts\stop-argos.ps1
```

Install as a user logon launcher:

```powershell
scripts\install-argos-desktop.ps1
```

By default this creates a Startup folder launcher:

```txt
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ArgosDesktopHub.cmd
```

If you specifically want to try Windows Task Scheduler instead:

```powershell
scripts\install-argos-desktop.ps1 -Method scheduled_task
```

Remove the logon task:

```powershell
scripts\uninstall-argos-desktop.ps1
```

The install script also sets user-level environment variables:

```txt
ARGOS_URL
ARGOS_MCP_URL
ARGOS_HOME
```

Open a new terminal after install to inherit those variables.

## Logs

```txt
.argos/argos-4020.out.log
.argos/argos-4020.err.log
.argos/argos-mcp-stdio.log
```

## Client Wiring

Generic HTTP MCP clients:

```txt
http://127.0.0.1:4020/mcp
```

Claude Desktop:

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

Local backends:

```txt
POST http://127.0.0.1:4020/api/capture
POST http://127.0.0.1:4020/api/context-pack
POST http://127.0.0.1:4020/mcp
```

ChatGPT web cannot reach `127.0.0.1`; expose ARGOS through a public HTTPS tunnel only when needed, and set `ARGOS_PUBLIC_URL` before starting Argos so citation URLs are correct.

## Safety

Keep the desktop hub bound to loopback for local use. Do not bind ARGOS to `0.0.0.0` or expose it publicly without an auth layer or a trusted private network such as Tailscale.

The event write path is safe for simultaneous local agents: events are inserted through Postgres transactions and locked per canon before hash-chain updates.
