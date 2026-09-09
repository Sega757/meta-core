# Observability Plane

The Observability Plane implements the **"Clean Trail" (Чистый след)**
principle: every perception, thought, and action in the system is appended
to a single local, immutable ledger — `event_stream.jsonl` — which every
other observability component reads passively and asynchronously. Nothing
here has write access to any other plane.

## Components

| Component | Stack | Interface | Role |
|---|---|---|---|
| `transponder.py` | Python | Writes `event_stream.jsonl` | Atomic `flush + os.fsync` event logging |
| `event_stream.jsonl` | Append-only local file | Shared read interface | The single source of truth for system history |
| `observer.py` | Python | Read-only parsing | Anomaly filtering (Huber Loss, Z-score), Trace DAG construction, loop detection |
| `log_sync.sh` + `log-sync.timer` | Bash, systemd, Git 2.30+ | Read-only, batched push | Syncs the local log to a remote Git repository every 5 minutes |

## Durability: why `flush + os.fsync`

`transponder.py` performs an atomic `flush` followed by an `os.fsync` system
call on every write. This forces the OS to commit the event to physical disk
immediately — the log survives a kernel panic or power failure, which is a
non-negotiable requirement for industrial forensic auditing.

## Telemetry flow

```mermaid
flowchart TD
    RE["Reasoning / Execution planes"] -->|generates event| TR["transponder.py\nflush + os.fsync"]
    TR --> EV[("event_stream.jsonl")]
    EV -->|async read| OB["observer.py"]
    OB --> DAG["Trace DAG +\nanomaly filtering"]
    EV -->|5-min timer| LS["log_sync.sh"]
    LS -->|git add / commit / push| GIT[("Remote Git repository")]
```

## Why this is safe to crash

Because `observer.py` and `log_sync.sh` only ever *read* the event stream,
neither one can corrupt it, and neither one blocks the Execution or
Reasoning planes if it crashes. SQLite's **WAL mode** additionally lets
`observer.py` run heavy analytical queries against the transaction database
without locking active writes — see
[ADR-0004](../decisions/0004-sqlite-wal-mode.md).

## The 5-minute sync gap

Real-time, synchronous remote logging would block on network latency and
GitHub/GitLab rate limits, breaking the sub-100ms CRUD target. META-CORE
accepts eventual consistency for remote telemetry (max 5-minute lag) to keep
local execution fast. Full trade-off analysis:
[ADR-0001](../decisions/0001-decoupled-telemetry-sync.md).

## Security properties

- **Tamper resistance** — a compromised Reasoning Plane has no socket or
  memory access to `observer.py`, so it cannot alter or delete telemetry.
- **Network fault isolation** — if the remote Git push fails, the local log
  is untouched and execution continues unblocked.
- **Rate-limit defense** — batching syncs to 5-minute windows keeps
  high-frequency PTAC loops from triggering GitHub/GitLab API throttling.

## Open questions

- File rotation / retention policy for `event_stream.jsonl` (unbounded
  growth risk under long-running deployments).
- Locking strategy in `transponder.py` for concurrent writers (multiple
  parallel agent processes).
- Authentication method `log_sync.sh` uses against the remote Git host
  (SSH deploy key vs. HTTPS token).
- Corruption handling for a truncated/incomplete write if a process dies
  mid-append.
- Threshold values for the Huber Loss / Z-score anomaly filters in
  `observer.py`, and the output schema for the generated Trace DAGs.

See [`docs/open-questions.md`](../open-questions.md) for the full list.
