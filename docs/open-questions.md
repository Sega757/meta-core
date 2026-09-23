# Open Questions

The META-CORE blueprint specifies *what* boundary each component enforces,
but a number of interfaces and thresholds are referenced without a concrete
specification. This page consolidates every such gap in one place so they
can be tracked and closed deliberately, instead of discovered piecemeal
during implementation. Each item links back to the page where it surfaced.

## IPC & transport

- **AIDL Gateway ↔ Executor contract** — the interface definition
  (method signatures, data types) bridging the Node.js API Backend and
  `agent.py` is not specified. ([Execution Plane](architecture/execution-plane.md),
  [Reasoning Plane](architecture/reasoning-plane.md))
- **AIDL transport layer** — whether the bridge runs over stdio, Unix domain
  sockets, TCP loopback, or named pipes, and what serializes the payload
  between TypeScript and Python. ([Component Connectivity](architecture/component-connectivity.md))
- **Sidecar transport protocol** — the network/IPC mechanism (HTTP, Unix
  socket, gRPC) carrying Decision Packets from `agent.py` to the Control
  Plane sidecar. ([Control Plane](architecture/control-plane.md))
- **Kill-Switch termination signal** — whether the emergency stop is a
  `SIGKILL`, `SIGTERM`, or a sidecar-issued stop request/webhook.
  ([Control Plane](architecture/control-plane.md))
- **AIDL security handshake** — how the Node.js backend authenticates the
  connecting `agent.py` engine, so an unauthorized process can't spoof it.
  ([Assembly Stages](deployment/assembly-stages.md))

## Safety logic

- **L0–L3 escalation rules** — the concrete evaluation logic and numeric
  thresholds distinguishing the four escalation tiers.
  ([L-E-J-D-A-S framework](security/l-e-j-d-a-s-framework.md))
- **Validation-failure feedback loop** — whether a rejected Decision Packet's
  detail routes back to `agent.py` to trigger an automatic corrective PTAC
  retry, or requires human intervention. ([Reasoning Plane](architecture/reasoning-plane.md))
- **Kill-Switch numeric ceilings** — execution-time, memory, and absolute
  per-run token ceilings are still unset. Loop-repetition and spend-velocity
  are now fixed by [ADR-0011](decisions/0011-loop-detection-algorithm.md)
  and [ADR-0012](decisions/0012-ai-gateway-egress-implementation.md).
  ([L-E-J-D-A-S framework](security/l-e-j-d-a-s-framework.md))
- ~~Active loop-detection algorithm~~ — resolved:
  [ADR-0011](decisions/0011-loop-detection-algorithm.md) specifies a
  step-counter + semantic-hash + spend-velocity check run before dispatch.
  ([Control Plane](architecture/control-plane.md))
- **Post-kill state recovery** — rollback protocol for transactions cut off
  mid-execution by an L3 kill. ([Control Plane](architecture/control-plane.md))

## Data & storage

- **EGDS engine** — the underlying software running the Knowledge Object
  store (plain relational tables, `pgvector`, an embedded key-value engine).
  ([Data Architecture](architecture/data-architecture.md))
- **Embedding pipeline** — which model (local or external API) populates the
  `embedding` field on a Knowledge Object. ([Data Architecture](architecture/data-architecture.md))
- **Subject/predicate normalization** — casing, trimming, and encoding rules
  applied before computing the SHA-256 fact ID. ([Data Architecture](architecture/data-architecture.md))
- **SHA-256 collision handling** — no fallback/resolution framework is
  defined. ([Data Architecture](architecture/data-architecture.md))
- **WAL checkpoint policy** — automated checkpoint thresholds or explicit
  `PRAGMA wal_checkpoint` scheduling to bound `-wal` file growth.
  ([ADR-0004](decisions/0004-sqlite-wal-mode.md))
- **Connection pool sizing** — max concurrent connection limits for the
  SQLite driver inside the Next.js API server. ([ADR-0004](decisions/0004-sqlite-wal-mode.md))

## Validation & schema

- **Zod ↔ JSON Schema drift prevention** — how the Zod-to-JSON-Schema
  compilation step is automated and kept current at build time.
  ([ADR-0006](decisions/0006-dual-schema-validation.md))
- **Validation-error reporting pipeline** — the interface routing a Zod or
  JSON Schema validation failure back to the agent for self-correction.
  ([ADR-0006](decisions/0006-dual-schema-validation.md))

## Queueing & concurrency

- **BullMQ idempotency-key generation** — the concrete algorithm workers use
  to derive deduplication keys. ([Execution Plane](architecture/execution-plane.md))
- **Redis lock TTL / expiry policy** — no defined time-to-live for
  distributed agent locks, which risks a deadlock if a worker crashes
  mid-execution. ([ADR-0005](decisions/0005-redis-bullmq-execution-only.md))
- **Dead-letter queue behavior** — recovery procedure when an idempotent
  worker repeatedly fails under the at-least-once delivery guarantee.
  ([ADR-0005](decisions/0005-redis-bullmq-execution-only.md))
- **Concurrency-breach behavior** — what happens to a request that exceeds
  the 1–2 task Redis concurrency threshold (queued vs. rejected).
  ([Component Connectivity](architecture/component-connectivity.md))

## Telemetry & observability

- **Event log rotation/retention** — no truncation or archival policy for
  `event_stream.jsonl`, risking unbounded disk growth.
  ([Observability Plane](architecture/observability-plane.md))
- **Concurrent-writer locking** — the mechanism `transponder.py` uses when
  multiple parallel agent processes append simultaneously.
  ([Observability Plane](architecture/observability-plane.md))
- **Git authentication** — whether `log_sync.sh` uses SSH deploy keys or
  HTTPS tokens against the remote repository, and how credentials are
  provisioned. ([ADR-0001](decisions/0001-decoupled-telemetry-sync.md))
- **Partial-write corruption handling** — behavior if a process terminates
  mid-append to `event_stream.jsonl`. ([Observability Plane](architecture/observability-plane.md))
- ~~Anomaly-detection thresholds (Huber Loss / Z-score) and Trace DAG
  schema~~ — superseded:
  [ADR-0015](decisions/0015-claim-level-trace-evaluation.md) replaces both
  with OpenTelemetry-style span trees and trace-level scoring.
  ([Observability Plane](architecture/observability-plane.md))
- **Trace-eval pass/fail threshold** — the Tool-Call Accuracy / Agent-Goal
  Accuracy cutoff introduced by
  [ADR-0015](decisions/0015-claim-level-trace-evaluation.md) is not yet
  fixed. ([Observability Plane](architecture/observability-plane.md))

## Deployment

- **`docker-compose.yml` contents** — the path
  `/containerization/docker-compose.yml` is referenced but the file itself
  is not yet written. ([ADR-0007](decisions/0007-multi-container-deployment.md))
- **Sandbox jail policy** — the concrete OS-level mechanism (AppArmor,
  gVisor, or equivalent) enforcing the blocked-socket rule.
  ([Deployment Requirements](deployment/requirements.md))
- **`.env` contract** — the full set of environment variables linking Redis
  to BullMQ and other Stage 1 services. ([Deployment Requirements](deployment/requirements.md))
- **Process supervisor** — PM2, a systemd unit, or a container-native
  restart policy for the Node.js API in production.
  ([Deployment Requirements](deployment/requirements.md))
- **Ed25519 key rotation policy** — distribution and lifecycle management of
  the public keys `agent.py` uses to verify command authenticity.
  ([Deployment Requirements](deployment/requirements.md))
- **Package version pinning** — exact `cryptography`/`numpy` version
  requirements are unspecified. ([Deployment Requirements](deployment/requirements.md))
- **Stage 1 test suite** — the concrete commands/parameters for the
  concurrency and write-lock verification tests.
  ([Assembly Stages](deployment/assembly-stages.md))

## Raised by external audits

- **Stack reconciliation, TOCTOU handling, formal verification scope, and a
  possible "Economics" scorecard field** — see
  [Audit 0001](audits/0001-go-grpc-tlaplus-stack-audit.md#open-questions-raised-by-this-audit)
  for the full detail on each.

## Reasoning

- **LLM call fault tolerance** — retry/backoff logic for a failed API call
  inside the PTAC cycle. ([Reasoning Plane](architecture/reasoning-plane.md))
- ~~Context token budgeting~~ — resolved:
  [ADR-0014](decisions/0014-context-budgeting.md) fixes percentage bands
  per prompt component. ([Reasoning Plane](architecture/reasoning-plane.md))
- **Intent pre-filter model and threshold** — which classifier and score
  cutoff screens unstructured external content before it enters the
  Think-phase prompt, and whether flagged content is dropped silently or
  logged. ([Reasoning Plane](architecture/reasoning-plane.md))
- **ADK 2.0 binding** — the exact interfaces binding Neocortex actions to
  ADK 2.0 primitives. ([Reasoning Plane](architecture/reasoning-plane.md))
- **Self-correction retry limit** — the maximum number of schema-validation
  retries permitted in Check before the agent raises an operational
  exception. ([Reasoning Plane](architecture/reasoning-plane.md))
