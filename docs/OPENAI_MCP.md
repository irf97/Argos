# Connect ARGOS to GPT / ChatGPT with MCP

ARGOS exposes a remote MCP endpoint at:

```txt
POST /mcp
```

For OpenAI / ChatGPT compatibility, ARGOS now exposes:

- `search`: read-only search over ARGOS events and canons.
- `fetch`: read one search result in full.
- Existing developer-mode tools: `argos_state`, `argos_search`, `argos_capture`, `argos_pack`, `argos_propose`, `argos_crawl`, and `argos_crawl_and_ingest`.

## Local status

ARGOS is running locally on:

```txt
http://127.0.0.1:4020
```

Health:

```powershell
Invoke-RestMethod http://127.0.0.1:4020/api/health
```

MCP tool list:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:4020/mcp `
  -ContentType 'application/json' `
  -Body '{"jsonrpc":"2.0","id":"tools","method":"tools/list"}'
```

## ChatGPT web

ChatGPT cannot connect to `localhost` on your machine. To use ARGOS from ChatGPT web, expose ARGOS through a public HTTPS URL, then add that URL in ChatGPT Apps / Developer mode.

Example target URL:

```txt
https://your-public-tunnel.example/mcp
```

Start ARGOS with the public URL set so search results produce usable citation URLs:

```powershell
cd C:\AI\Projects\Argos\wei\argos-codex-cli-pack
$env:PORT="4020"
$env:ARGOS_PUBLIC_URL="https://your-public-tunnel.example"
mix phx.server
```

Then in ChatGPT:

1. Enable Developer mode in ChatGPT Apps advanced settings.
2. Create an app from your remote MCP server.
3. Server URL: `https://your-public-tunnel.example/mcp`.
4. For data-only use, enable `search` and `fetch`.
5. For write-capable development use, enable `argos_capture` only when you want ChatGPT to write events.

## Prompt

Use this after connecting the app:

```txt
Use the ARGOS app only. First call search with query "argos mcp" and inspect the results. Then fetch the most relevant result. If I explicitly ask you to write memory, call argos_capture with kind "manual_note" and canon_id "operator"; otherwise stay read-only.
```

## Responses API

Use a remote MCP tool with your public URL:

```json
{
  "type": "mcp",
  "server_label": "argos",
  "server_url": "https://your-public-tunnel.example/mcp",
  "allowed_tools": ["search", "fetch"],
  "require_approval": "never"
}
```

For write-capable testing, add `argos_capture` to `allowed_tools` and keep approval enabled.
