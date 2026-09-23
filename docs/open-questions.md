# Open Questions & Concrete Specifications

The META-CORE blueprint specifies the boundaries each component enforces. This document consolidates the architectural resolutions and specifications for all open questions across transport, safety, data, validation, queueing, telemetry, deployment, and audit recommendations.

---

## 1. IPC & Transport

- **AIDL Gateway ↔ Executor contract**: Standardized via gRPC using Protocol Buffers (`metacore.v1.ExecutionService`). Exposes explicit methods:
  - `ExecuteAction(ActionRequest) returns (ActionResponse)`
  - `GetState(StateRequest) returns (StateResponse)`
  - `HealthCheck(HealthRequest) returns (HealthResponse)`
- **AIDL transport layer**: gRPC over TCP loopback / internal container network with mTLS or token-based authentication. Serialization uses Protobuf v3 for strict type guarantees across Go / Node.js and Python.
- **Sidecar transport protocol**: gRPC over HTTP/2 (`metacore.v1.ValidatorService`) between `reasoning-worker` and `control-sidecar`.
- **Kill-Switch termination signal**: Two-phase termination protocol:
  1. Sidecar issues `HaltExecution` gRPC signal to Execution Plane to lock state and abort active tasks.
  2. Sidecar issues `SIGTERM` to the reasoning process; if process fails to exit within 5 seconds, issues `SIGKILL`.
- **AIDL security handshake**: HMAC-SHA256 handshake on socket initialization using a shared secret injected via container volume secrets.

---

## 2. Safety Logic

- **L0–L3 escalation rules**:
  - **L0 (Info)**: Non-blocking audit event. Logged to `event_stream.jsonl` and execution proceeds immediately.
  - **L1 (Warning / Self-Correct)**: Schema mismatch or minor policy violation. Decision Packet rejected with detailed failure payload routed back to `agent.py` for automated PTAC retry (max 3 retries).
  - **L2 (Block / Authorization)**: Severe policy breach (out-of-bounds state mutation, unauthorized endpoint call). Action blocked, execution paused, operator alert dispatched via webhook.
  - **L3 (Hard Panic / Kill-Switch)**: Unhandled loop, OOM, timeout, or safety invariant violation. Immediate process kill (`SIGKILL`), execution state locked, transaction rolled back.
- **Validation-failure feedback loop**: L1 rejection returns a structured `ValidationFailure` message containing JSON Pointer errors to `agent.py`. The agent incorporates the error into the Think context and attempts self-correction up to 3 times before escalating to L2.
- **Kill-Switch numeric ceilings**:
  - Max Execution Time: 30 seconds per PTAC cycle.
  - Max Memory Allocation: 512MB for `reasoning-worker`.
  - Max Token Budget: 100,000 tokens per session.
  - Max Loop Repetition: 3 identical consecutive Decision Packet hashes.
- **Active loop-detection algorithm**: Resolved via [ADR-0011](decisions/0011-loop-detection-algorithm.md). Sliding window comparing SHA-256 hashes of the last 5 Decision Packets. Triggers L3 if 3 consecutive identical actions occur or >10 PTAC cycles complete without advancing state.
- **Post-kill state recovery**: All Execution Plane state mutations execute inside transactional blocks (`BEGIN IMMEDIATE...COMMIT`) in SQLite WAL mode. On L3 trigger, pending uncommitted transactions automatically undergo `ROLLBACK`.

---

## 3. Data & Storage

- **EGDS engine**: SQLite with `WAL` mode enabled, using `sqlite-vec` extension for local vector storage MVP (see [ADR-0010](decisions/0010-sqlite-for-vector-storage-mvp.md)). Provenance typing defined via [ADR-0013](decisions/0013-provenance-typed-knowledge-objects.md).
- **Embedding pipeline**: Local `sentence-transformers` (`all-MiniLM-L6-v2`) or external provider embedding (`text-embedding-3-small`) routed strictly through the Egress Proxy ([ADR-0012](decisions/0012-ai-gateway-egress-implementation.md)).
- **Subject/predicate normalization**: `lowercase(trim(subject))` and `lowercase(trim(predicate))` UTF-8 strings before computing SHA-256 Fact ID.
- **SHA-256 collision handling**: Deterministic check: if `SHA-256(subject || predicate)` collides with an existing fact holding different text, append salt `|| sequence_id`.
- **WAL checkpoint policy**: Passive checkpoint triggered every 1000 pages (~4MB) via `PRAGMA wal_autocheckpoint = 1000;`, plus daily scheduled `PRAGMA wal_checkpoint(TRUNCATE);`.
- **Connection pool sizing**: Single write connection (`max: 1`) to eliminate write lock contention in SQLite WAL, plus up to 10 concurrent read connections.

---

## 4. Validation & Schema

- **Zod ↔ JSON Schema drift prevention**: Automated build step (`npm run build:schemas`) using `zod-to-json-schema` to compile TypeScript Zod definitions to JSON Schema 2020-12 specs before container building.
- **Validation-error reporting pipeline**: Errors formatted as JSON Schema 2020-12 validation output objects (RFC 7396) and sent to Reasoning Plane via gRPC error details.

---

## 5. Queueing & Concurrency

- **BullMQ idempotency-key generation**: `SHA-256(decision_packet_id || timestamp_10s_window)`.
- **Redis lock TTL / expiry policy**: Default lock TTL of 15 seconds with heartbeat renewal every 5 seconds during execution. Auto-released on process termination or timeout.
- **Dead-letter queue behavior**: Jobs failing 3 attempts with exponential backoff (1s, 5s, 25s) are moved to `dead-letter-queue` and trigger an operator alert.
- **Concurrency-breach behavior**: Requests exceeding the 1–2 task worker limit are held in BullMQ FIFO queue. If queue depth exceeds 100, API rejects incoming requests with HTTP 429 (`TOO_MANY_REQUESTS`).

---

## 6. Telemetry & Observability

- **Event log rotation/retention**: Daily rotation via `logrotate` with 14-day retention and max 1GB total log volume limit.
- **Concurrent-writer locking**: POSIX `flock` file locking in `transponder.py` combined with atomic append mode (`O_APPEND`) and `os.fsync()` flushing.
- **Git authentication**: SSH deploy key mounted as a read-only secret volume inside the `log_sync.sh` container.
- **Partial-write corruption handling**: Line-by-line JSON stream parser on startup. Corrupted lines are quarantined to `event_stream.corrupted.log` without breaking full stream recovery.
- **Anomaly detection & Trace DAG**: Superseded by [ADR-0015](decisions/0015-claim-level-trace-evaluation.md) (OpenTelemetry span trees & claim-level trace scoring).
- **Trace-eval pass/fail threshold**: Tool-Call Accuracy / Agent-Goal Accuracy cutoff parameters defined per ADR-0015.

---

## 7. Deployment

- **`docker-compose.yml` contents**: Implemented under `/containerization/docker-compose.yml` with 5 microservices:
  - `execution-api` (Go / Node backend)
  - `reasoning-worker` (Python PTAC engine)
  - `control-sidecar` (Validator & Kill-Switch)
  - `egress-proxy` (Squid outbound LLM whitelist)
  - `redis-queue` (BullMQ state storage)
- **Sandbox jail policy**: Docker internal network isolation (`internal: true`) for `reasoning-net` combined with AppArmor profile blocking raw socket creation.
- **`.env` contract**: Standardized configuration variables defined in `.env.example`:
  ```env
  EXECUTION_PORT=8080
  GRPC_PORT=50051
  CONTROL_SIDE_PORT=50052
  REDIS_HOST=redis-queue
  REDIS_PORT=6379
  DB_PATH=/var/data/metacore.db
  ```
- **Process supervisor**: Docker container restart policy (`restart: unless-stopped`) with healthcheck dependencies.
- **Ed25519 key rotation policy**: Keys mounted from read-only secret volume, rotated every 90 days.
- **Package version pinning**: Strictly pinned in `requirements.txt` (Python 3.12) and `go.mod` (Go 1.22).
- **Stage 1 test suite**: `go test -v -race ./...` for race detection and `k6` benchmark running 50 concurrent virtual users against mutation endpoints.

---

## 8. Raised by External Audits

- **Stack reconciliation**: Unified gRPC/Protobuf contract allows seamless substitution of the Execution Plane implementation (`go-metacore` or Node.js) while maintaining full architectural boundaries.
- **TOCTOU handling**: **State-Bound Capability Tokens**: Control Plane issues cryptographic tokens signed with Ed25519, valid for 500ms and bound to state snapshot hash `S_t`. Execution Plane re-verifies token against live state immediately prior to state commit.
- **Formal verification**: Control Plane state transitions modeled in TLA+ (`docs/verification/control_plane.tla`).
- **Cost/telemetry field**: "Economics" metric added to telemetry, tracking cumulative token costs and CPU/GPU compute time per action.
- **Replay determinism bar**: `event_stream.jsonl` extended to record `random_seed`, `model_weights_hash`, and `prompt_sha256`.

---

## 9. Reasoning

- **LLM call fault tolerance**: Exponential backoff with jitter (1s initial, 32s max, 4 retries max) on HTTP 429/5xx status codes from LLM providers.
- **Context token budgeting**: Context budgeting rules defined via [ADR-0014](decisions/0014-context-budgeting.md).
- **ADK 2.0 binding**: Neocortex actions wrapped as standard Google ADK 2.0 `Tool` instances.
- **Self-correction retry limit**: Capped at 3 retries per PTAC cycle; exceeding this limit triggers L2 escalation.
