# Execution Plane

The Execution Plane is the only layer in META-CORE with write privileges. It
is a deliberately **tightly coupled** web stack — the one place in the
architecture where we trade isolation for latency, because it has to
guarantee sub-100ms CRUD transactions and every other plane depends on it
for persistence (the Reasoning Plane holds no state of its own).

## Components

| Component | Technology | Role |
|---|---|---|
| API Backend | Node.js v20+ (LTS), Next.js, TypeScript | Runs HTTP endpoints, hosts the AIDL IPC gateway to `agent.py`, orchestrates BullMQ workers |
| Transaction database | SQLite, Write-Ahead Logging (WAL) mode | Persists transactional metadata, queue state, and configuration |
| Deterministic knowledge store | Structured tuple DB (EGDS) | Stores Knowledge Objects — see [Data Architecture](data-architecture.md) |
| Task queue | Redis + BullMQ | Asynchronous parsing / generation / planning jobs, at-least-once delivery |
| Validation | Zod (TypeScript) | Rigid runtime type-checking of inbound arguments before any DB write |

## Transaction flow

```mermaid
flowchart TD
    A[Client / IPC Gateway] --> B[Enqueue BullMQ task]
    B --> C{Acquire Redis lock\n1-2 tasks / agent}
    C -->|granted| D[Idempotent worker executes]
    C -->|denied| B
    D --> E[SQLite WAL transaction\nSHA-256 verified Knowledge Object]
    E --> F[Append event_stream.jsonl\n"clean trail"]
```

## Why it's tightly coupled (and why that's safe)

Unlike the Reasoning and Observability planes, the Execution stack is
integrated in-process to eliminate serialization and network hops on the hot
path. This is safe *only* because the plane that could abuse that speed —
the LLM — has no credentials to reach it directly; every inbound mutation
still has to arrive as a validated Decision Packet through the IPC bridge.

## Security properties

- **Prompt-injection air-gap** — database credentials live exclusively in
  the Node.js process; `agent.py` never has them.
- **Idempotency** — BullMQ's at-least-once delivery means workers must be
  idempotent, so a network retry can never double-apply a state change.
- **Rate-limit defense** — Redis distributed locks cap each agent to 1–2
  concurrent tasks, preventing a runaway loop from exhausting external API
  quotas.
- **Schema gate** — Zod (runtime) and JSON Schema 2020-12 (from the
  Reasoning Plane) both validate before a write is attempted.

## Open questions

- Exact schema/contract of the AIDL IPC bridge between this plane and
  `agent.py`.
- The deduplication-key algorithm BullMQ workers use to guarantee
  idempotency.

See [`docs/open-questions.md`](../open-questions.md) for the full list, and
[ADR-0002](../decisions/0002-execution-plane-exclusive-db-access.md) for the
decision to keep DB credentials exclusively here.
