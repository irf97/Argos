#!/usr/bin/env python3
"""
Stdio-to-HTTP MCP bridge for ARGOS.

Claude Desktop launches this script as a local MCP server. The script keeps
stdout reserved for newline-delimited JSON-RPC and forwards requests to the
ARGOS HTTP MCP endpoint.
"""

import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request


ARGOS_URL = os.environ.get("ARGOS_URL", "http://127.0.0.1:4020").rstrip("/")
ARGOS_MCP_URL = os.environ.get("ARGOS_MCP_URL", f"{ARGOS_URL}/mcp")
ARGOS_TOKEN = os.environ.get("ARGOS_TOKEN", "")
ARGOS_MCP_TIMEOUT = float(os.environ.get("ARGOS_MCP_TIMEOUT", "30"))
DEFAULT_PROTOCOL_VERSION = os.environ.get("MCP_PROTOCOL_VERSION", "2025-06-18")
DEFAULT_LOG_PATH = pathlib.Path(__file__).resolve().parents[1] / ".argos" / "argos-mcp-stdio.log"
ARGOS_MCP_LOG = os.environ.get("ARGOS_MCP_LOG", str(DEFAULT_LOG_PATH))


def log(message):
    line = f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] [argos-mcp-stdio] {message}"
    print(line, file=sys.stderr, flush=True)

    try:
        pathlib.Path(ARGOS_MCP_LOG).parent.mkdir(parents=True, exist_ok=True)
        with open(ARGOS_MCP_LOG, "a", encoding="utf-8") as log_file:
            log_file.write(line + "\n")
    except OSError:
        pass


def request_id(message):
    if isinstance(message, dict) and "id" in message:
        return message.get("id")
    return None


def is_request(message):
    return isinstance(message, dict) and "id" in message


def rpc_error(message, code, error_message):
    if not is_request(message):
        return None

    return {
        "jsonrpc": "2.0",
        "id": request_id(message),
        "error": {"code": code, "message": error_message},
    }


def protocol_version(message):
    params = message.get("params") if isinstance(message, dict) else None

    if isinstance(params, dict) and isinstance(params.get("protocolVersion"), str):
        return params["protocolVersion"]

    return DEFAULT_PROTOCOL_VERSION


def parse_sse_response(text):
    for line in text.splitlines():
        if line.startswith("data:"):
            payload = line.removeprefix("data:").strip()

            if payload and payload != "[DONE]":
                return json.loads(payload)

    return None


def forward(message):
    body = json.dumps(message, separators=(",", ":")).encode("utf-8")
    method = message.get("method") if isinstance(message, dict) else None
    started_at = time.monotonic()

    log(f"incoming id={request_id(message)!r} method={method!r}")

    request = urllib.request.Request(ARGOS_MCP_URL, data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    request.add_header("Accept", "application/json, text/event-stream")
    request.add_header("MCP-Protocol-Version", protocol_version(message))

    if ARGOS_TOKEN:
        request.add_header("Authorization", f"Bearer {ARGOS_TOKEN}")

    try:
        with urllib.request.urlopen(request, timeout=ARGOS_MCP_TIMEOUT) as response:
            response_body = response.read()
            elapsed_ms = int((time.monotonic() - started_at) * 1000)
            log(
                f"http status={response.status} elapsed_ms={elapsed_ms} "
                f"id={request_id(message)!r} method={method!r}"
            )

            if response.status == 202 or not response_body:
                return None

            text = response_body.decode("utf-8")
            content_type = response.headers.get("Content-Type", "")

            if "text/event-stream" in content_type:
                return parse_sse_response(text)

            return json.loads(text)

    except urllib.error.HTTPError as exc:
        response_body = exc.read()
        elapsed_ms = int((time.monotonic() - started_at) * 1000)
        log(
            f"http_error status={exc.code} elapsed_ms={elapsed_ms} "
            f"id={request_id(message)!r} method={method!r}"
        )

        if response_body:
            try:
                return json.loads(response_body.decode("utf-8"))
            except json.JSONDecodeError:
                pass

        return rpc_error(message, -32000, f"ARGOS MCP HTTP error {exc.code}")

    except (OSError, TimeoutError) as exc:
        elapsed_ms = int((time.monotonic() - started_at) * 1000)
        log(
            f"bridge_error elapsed_ms={elapsed_ms} id={request_id(message)!r} "
            f"method={method!r} error={exc}"
        )
        return rpc_error(message, -32000, f"ARGOS MCP bridge error: {exc}")


def write_response(response):
    if response is None:
        log("notification accepted; no stdout response")
        return

    sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
    sys.stdout.flush()
    log(f"wrote stdout response id={request_id(response)!r}")


def main():
    log(f"forwarding stdio MCP to {ARGOS_MCP_URL}")

    for raw_line in sys.stdin.buffer:
        line = raw_line.decode("utf-8").strip()

        if not line:
            continue

        try:
            message = json.loads(line)
        except json.JSONDecodeError as exc:
            log(f"discarding invalid JSON-RPC message: {exc}")
            continue

        write_response(forward(message))


if __name__ == "__main__":
    main()
