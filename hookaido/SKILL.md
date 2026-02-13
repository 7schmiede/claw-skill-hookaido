---
name: hookaido
description: Create, review, and operate Hookaido webhook queue setups. Use when tasks involve Hookaidofile authoring, `hookaido` CLI commands (`run`, `config fmt`, `config validate`, `mcp serve`), pull-mode consumers (`dequeue`/`ack`/`nack`/`extend`), Admin API queue triage (health, backlog, DLQ), or production hardening for Hookaido ingress and delivery.
---

# Hookaido

## Overview

Implement and troubleshoot Hookaido with a config-first workflow: edit `Hookaidofile`, validate, run, exercise ingress/pull flows, then diagnose queue health and DLQ behavior.
Use conservative, reversible changes and validate before runtime operations.

## Workflow

1. Confirm target topology: pull mode, push mode, outbound-only, or internal queue.
2. Inspect and update `Hookaidofile` minimally.
3. Run format and validation before starting or reloading:
   - `hookaido config fmt --config ./Hookaidofile`
   - `hookaido config validate --config ./Hookaidofile`
4. Start runtime and verify health:
   - `hookaido run --config ./Hookaidofile --db ./.data/hookaido.db`
   - `curl http://127.0.0.1:2019/healthz?details=1`
5. Validate end-to-end behavior:
   - ingress request accepted and queued
   - consumer dequeue and `ack`/`nack` path works
6. For incidents, inspect backlog and DLQ first, then mutate.

## Task Playbooks

### Configure Ingress and Pull Consumption

1. Define a route with explicit auth and pull path.
2. Keep secrets in env/file refs, never inline.
3. Verify route and global pull auth are consistent.
4. Test with a real webhook payload and a dequeue/ack cycle.

Prefer this baseline:

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

### Configure Push Delivery

1. Use push delivery only when inbound connectivity to the service is acceptable.
2. Set timeout and retry policy explicitly.
3. Validate downstream idempotency since delivery is at-least-once.

```hcl
/webhooks/stripe {
  auth hmac env:STRIPE_SIGNING_SECRET
  deliver "https://billing.internal/stripe" {
    retry exponential max 8 base 2s cap 2m jitter 0.2
    timeout 10s
  }
}
```

### Operate Queue and DLQ

1. Start with health details and backlog endpoints.
2. Inspect DLQ before requeue or delete.
3. If requeueing many items, explain expected impact and rollback path.
4. Require clear operator reason strings for mutating admin calls.

Use:

- `GET /healthz?details=1`
- `GET /backlog/trends`
- `GET /dlq`
- `POST /dlq/requeue`
- `POST /dlq/delete`

### Use MCP Mode for AI Operations

1. Default to `--role read` for diagnostics.
2. Enable mutations only with explicit operator intent:
   - `--enable-mutations --role operate --principal <identity>`
3. Enable runtime control only for admin workflows:
   - `--enable-runtime-control --role admin --pid-file <path>`
4. Include `reason` for mutation calls and keep it specific.

## Validation Checklist

- `hookaido config validate` returns success before runtime start/reload.
- Health endpoint is reachable and reports expected queue/backend state.
- Pull consumer can `dequeue`, `ack`, and `nack` with valid token.
- For push mode, retry/timeout behavior is explicitly configured.
- Any DLQ mutation is scoped, justified, and logged.

## Safety Rules

- Do not disable auth to "make tests pass."
- Do not suggest direct mutations before read-only diagnostics.
- Treat queue operations as at-least-once; require idempotent handlers.
- Keep secrets in `env:` or `file:` refs.

## References

- Read `references/operations.md` for command snippets and API payload templates.
