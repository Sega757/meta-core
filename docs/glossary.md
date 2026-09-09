# Glossary

| Term | Definition |
|---|---|
| **PTAC** | Perceive-Think-Act-Check — the deterministic four-phase planning cycle run by the Reasoning Plane on every agent turn. See [`docs/architecture/reasoning-plane.md`](architecture/reasoning-plane.md). |
| **Decision Packet** | A JSON Schema 2020-12 validated payload compiled by `agent.py` in the "Act" phase, describing exactly one proposed action. It is the only channel through which the Reasoning Plane can influence system state. |
| **Neocortex Engine** (`NeocortexSystem1Engine`) | The Python 3.12 / ADK 2.0 engine inside `agent.py` that drives the PTAC loop. |
| **Clean Trail** (Чистый след) | The principle that every perception, thought, and action is appended to `event_stream.jsonl` — an immutable, append-only ledger — rather than logged into a mutable store. |
| **EGDS** (ЕГДС) | The deterministic Knowledge Object store. Underlying engine is unspecified — see [open questions](open-questions.md). |
| **Knowledge Object (KO)** | A fact tuple `(id, subject, predicate, object, embedding, provenance)` where `id = SHA-256(subject \|\| predicate)`. See [`docs/architecture/data-architecture.md`](architecture/data-architecture.md). |
| **L-E-J-D-A-S** | The six-field safety framework (Legal, Ethical, Jurisdictional, Duty, Accountability, Safety) evaluated by `validator.py` on every Decision Packet. See [`docs/security/l-e-j-d-a-s-framework.md`](security/l-e-j-d-a-s-framework.md). |
| **L0–L3 escalation** | The four-tier severity ladder a Decision Packet is placed on after L-E-J-D-A-S evaluation, from L0 (pass) to L3 (fatal interdict + kill). |
| **AI Kill-Switch** | The sidecar daemon that terminates the Reasoning Plane process when execution time, memory, token consumption, or loop-detection bounds are breached. |
| **AIDL IPC bridge** | The interface bridging the Node.js API Gateway and the Python `agent.py` Executor. Transport and schema are not yet specified — see [open questions](open-questions.md). |
| **WAL** | SQLite Write-Ahead Logging mode. Lets the Observability Plane read concurrently with Execution Plane writes without locking. |
| **Sidecar container** | A container deployed alongside the Reasoning Plane but with its own isolated process/memory space, hosting `validator.py` and the AI Kill-Switch so a compromised model cannot reach them. |
| **Air Coefficient** | The Stage 5 self-audit metric used to track and prune architectural bloat (unused abstractions, naming drift) every 2–4 weeks. |
| **Transponder** (`transponder.py`) | The CLI utility that appends events to `event_stream.jsonl` using an atomic `flush + os.fsync`, guaranteeing durability across a crash. |
| **Observer** (`observer.py`) | The passive, read-only process that parses `event_stream.jsonl`, filters anomalies (Huber Loss / Z-score), and builds Trace DAGs of agent execution paths. |
| **Idempotent handler** | A BullMQ worker pattern that makes re-delivery of the same task (under BullMQ's at-least-once guarantee) safe — reprocessing does not corrupt state. |
