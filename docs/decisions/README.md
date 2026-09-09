# Architecture Decision Records

Each ADR documents one trade-off point in the META-CORE design: the
conflict that forced a choice, the alternatives considered, and why one was
picked. They follow a lightweight format: **Context → Decision →
Alternatives & trade-offs → Consequences**.

| ID | Title | Status |
|---|---|---|
| [0001](0001-decoupled-telemetry-sync.md) | Decoupled local telemetry with 5-minute batched remote sync | Accepted |
| [0002](0002-execution-plane-exclusive-db-access.md) | Execution Plane holds exclusive database write credentials | Accepted |
| [0003](0003-sidecar-isolated-safety-modules.md) | Validator and Kill-Switch run in an isolated sidecar container | Accepted |
| [0004](0004-sqlite-wal-mode.md) | SQLite in Write-Ahead Logging mode | Accepted |
| [0005](0005-redis-bullmq-execution-only.md) | Redis/BullMQ access restricted to the Execution Plane | Accepted |
| [0006](0006-dual-schema-validation.md) | Dual schema validation (Zod + JSON Schema 2020-12) | Accepted |
| [0007](0007-multi-container-deployment.md) | Multi-container deployment via Docker Compose | Accepted |
| [0008](0008-sequential-health-gated-bootstrap.md) | Sequential, health-gated stage bootstrap | Accepted |
| [0009](0009-egress-proxy-for-llm-calls.md) | Egress proxy whitelisting for outbound LLM API calls | Accepted |
| [0010](0010-sqlite-for-vector-storage-mvp.md) | SQLite-hosted vector storage for the MVP | Accepted |

All ten share a single recurring theme: wherever a performance or
convenience win required trusting the Reasoning Plane with more access, the
decision instead pays an isolation or latency cost to keep that plane
untrusted. See [`docs/architecture/overview.md`](../architecture/overview.md)
for how these decisions compose into the full system.
