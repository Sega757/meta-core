# META-CORE — Telemetry Layer v1.0

Portable agent-engine core. This repo contains the **working, tested** part of the
architecture: the decoupled telemetry bus that every META-CORE node writes to.
The rest of the design (Flow-Core, Control Plane, Chronos V3) is specified in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and tracked as roadmap.

## Core invariant

> A core never reports its state to a specific recipient. It publishes a fact via
> the Transponder. Anyone who needs state reads the event stream.

```
agent / ADK node ──► transponder.py ──(flock+fsync append)──► event_stream.jsonl
                                                                   │
                         observer.py (read-only) ◄─────────────────┤
                         rotate.sh  (100 MB → archive/*.gz) ◄──────┤
                         log_sync.sh (git batch push, 5 min) ◄─────┘
```

## Layout

| Path | Purpose |
|---|---|
| `telemetry/transponder.py` | Validates event (schema v1.0, 9-event ENUM), enriches, atomic append. Zero network/git. CLI + `emit()` API. |
| `telemetry/observer.py` | Passive parser: trace trees, handoff depth, cycles, orphan spawns, stale cores. Exit 0/1/2 = OK/WARN/CRITICAL. |
| `telemetry/log_sync.sh` | Batch `git commit/push` only if changes exist; flock; exponential backoff; errors → `log_sync.err`. |
| `telemetry/rotate.sh` | Copy+truncate rotation under the writer lock, gzip into `archive/`. |
| `schemas/event_bus_payload.v1.json` | JSON Schema 2020-12 contract. |
| `deploy/systemd/` | Timers for sync (5 min) and observer (1 min). |
| `examples/demo.py` | Two-core handoff + spawn simulation. |
| `tests/` | stdlib `unittest`, incl. 8-process concurrent write test. |

## Quick start

```bash
cp .env.example .env
make test     # 14 tests
make demo     # writes demo events, runs observer

export CORE_ID=core-001 EVENT_LOG_PATH=telemetry/event_stream.jsonl
python3 telemetry/transponder.py '{"event":"STEP_COMPLETED","execution_step":"18/42","data":{"status":"success"}}'
python3 telemetry/observer.py --json
```

From Python:

```python
from telemetry.transponder import emit
emit({"event": "STEP_STARTED", "core_id": "core-001", "trace_id": tid, "span_id": sid, "parent_span_id": parent})
```

Requirements: Python 3.10+ (stdlib only), bash, git, util-linux (`flock`). Linux/macOS (uses `fcntl`).

## Event contract (v1.0)

Required: `schema`, `event_id`, `core_id`, `event`, `timestamp`.
Events: `CORE_STARTED CORE_STOPPED HEARTBEAT STEP_STARTED STEP_COMPLETED STEP_FAILED SPAWN_REQUESTED SPAWN_COMPLETED FATAL_ERROR`.
Execution events (`STEP_*`, `SPAWN_*`) always carry `trace_id`/`span_id` — generated as a root span if the caller omits them.
Optional objects: `data`, `context_diff`, `guardrail_state`, `metrics`.

## Deploy (systemd)

```bash
sudo cp -r . /opt/meta-core && sudo useradd -r metacore && sudo chown -R metacore /opt/meta-core
sudo cp deploy/systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now log-sync.timer observer.timer
```

Wire `observer.service` exit code 2 to your kill switch (`OnFailure=`).

## Decisions

- **ADR-001** — No git in the Transponder. Push is batched by `log_sync.sh` (rate limits, latency, lock contention).
- **ADR-002** — `trace_id` conditional: optional for lifecycle/heartbeat, auto-generated for execution events.
- **ADR-003** — Rotation is copy+truncate under the writer's flock (rename could lose in-flight appends).

## License

TBD
