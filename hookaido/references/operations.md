# Hookaido Operations Reference

Use this file for concrete command syntax and request payloads.

## Install Hookaido

Preferred in OpenClaw:

- Use one of the skill installer actions from `metadata.openclaw.install` (platform + architecture specific download).
- Choose the artifact that matches your host architecture (`amd64` or `arm64`).
- The OpenClaw download URLs are currently pinned to Hookaido `v1.2.0`.
- macOS/Linux download installers extract to `~/.local/bin` (with `stripComponents: 1`).
- Windows download installers extract to `~/.openclaw/tools/hookaido`.

Direct CLI fallback:

```bash
go install github.com/nuetzliches/hookaido/cmd/hookaido@latest
```

Release-binary fallback from this skill folder:

```bash
bash {baseDir}/scripts/install_hookaido.sh
```

Optional pins/overrides for the installer script:

```bash
# Pin version (example)
HOOKAIDO_VERSION=v1.2.0 bash {baseDir}/scripts/install_hookaido.sh

# Custom install location
HOOKAIDO_INSTALL_DIR="$HOME/bin" bash {baseDir}/scripts/install_hookaido.sh
```

## Core CLI Commands

```bash
# Validate and format config
hookaido config fmt --config ./Hookaidofile
hookaido config validate --config ./Hookaidofile

# Start runtime
hookaido run --config ./Hookaidofile --db ./.data/hookaido.db

# Start runtime with live config watch
hookaido run --config ./Hookaidofile --db ./.data/hookaido.db --watch

# Start MCP server (read-only)
hookaido mcp serve --config ./Hookaidofile --db ./.data/hookaido.db --role read
```

## Minimal Pull-Mode Config

```hcl
ingress {
  listen :8080
}

pull_api {
  listen :9443
  auth token env:HOOKAIDO_PULL_TOKEN
}

/webhooks/github {
  auth hmac env:HOOKAIDO_INGRESS_SECRET
  pull { path /pull/github }
}
```

## Pull API Calls

Assume base URL `http://localhost:9443/pull/github` and token in `HOOKAIDO_PULL_TOKEN`.

```bash
# Dequeue
curl -sS -X POST "http://localhost:9443/pull/github/dequeue" \
  -H "Authorization: Bearer $HOOKAIDO_PULL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"batch":10,"lease_ttl":"30s","max_wait":"5s"}'

# Ack
curl -sS -X POST "http://localhost:9443/pull/github/ack" \
  -H "Authorization: Bearer $HOOKAIDO_PULL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"lease_id":"lease_xyz"}'

# Nack (requeue with delay)
curl -sS -X POST "http://localhost:9443/pull/github/nack" \
  -H "Authorization: Bearer $HOOKAIDO_PULL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"lease_id":"lease_xyz","delay":"5s","dead":false}'

# Extend lease
curl -sS -X POST "http://localhost:9443/pull/github/extend" \
  -H "Authorization: Bearer $HOOKAIDO_PULL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"lease_id":"lease_xyz","lease_ttl":"30s"}'
```

## Admin API Reads

```bash
# Health summary
curl -sS "http://127.0.0.1:2019/healthz"

# Detailed diagnostics
curl -sS "http://127.0.0.1:2019/healthz?details=1"

# Backlog trends
curl -sS "http://127.0.0.1:2019/backlog/trends?window=1h&step=5m"

# Dead-letter queue
curl -sS "http://127.0.0.1:2019/dlq?limit=50"
```

## Admin API Mutations

Use `X-Hookaido-Audit-Reason` and keep reasons actionable.

```bash
# Requeue DLQ items
curl -sS -X POST "http://127.0.0.1:2019/dlq/requeue" \
  -H "Content-Type: application/json" \
  -H "X-Hookaido-Audit-Reason: retry-after-fix" \
  -d '{"ids":["evt_1","evt_2"]}'

# Delete DLQ items
curl -sS -X POST "http://127.0.0.1:2019/dlq/delete" \
  -H "Content-Type: application/json" \
  -H "X-Hookaido-Audit-Reason: remove-invalid-payloads" \
  -d '{"ids":["evt_3"]}'
```

## MCP Role Patterns

```bash
# Read-only diagnostics
hookaido mcp serve --config ./Hookaidofile --db ./.data/hookaido.db --role read

# Queue mutation workflows
hookaido mcp serve --config ./Hookaidofile --db ./.data/hookaido.db \
  --enable-mutations --role operate --principal ops@example.test

# Full admin control (includes runtime operations)
hookaido mcp serve --config ./Hookaidofile --db ./.data/hookaido.db \
  --enable-mutations --enable-runtime-control --role admin \
  --principal ops@example.test --pid-file ./hookaido.pid
```
