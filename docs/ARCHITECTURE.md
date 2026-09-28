# META-CORE Architecture — status map

Legend: ✅ implemented & tested in this repo · 📐 specified, not implemented · ⚠️ needs verification before building

## Three-plane split
| Plane | Components | Status |
|---|---|---|
| Telemetry | transponder, event log, observer, log_sync, rotation | ✅ |
| Reasoning | PTAC loop (Perceive-Think-Act-Check), Decision Packet JSON output | 📐 |
| Control | validator (Decision Packet risk L0–L3, L-E-J-D-A-S filter), kill switch sidecar | 📐 — observer exit code 2 is the trigger hook |
| Execution | Node.js API, SQLite WAL, BullMQ/Redis | 📐 |

## Flow-Core (claims FSM, 12 states)
- A: RECEIVED → INTENT_EXTRACTED → TYPE_CLASSIFIED → EMOTION_ANALYZED
- B: ROUTED → CONTEXT_LINKED → ACTION_PLANNED → ACTION_EXECUTED → SLA_MONITORING
- C: RESOLVED / ESCALATED → LEGAL_PROCEEDING → ARCHIVED
- SLA timers: T_ACK 24h, T_WARN 50%, T_ESCALATE 80%, T_BREACH 100%.
- Status: 📐. Open ADR: SCXML FSM inside nodes vs Petri nets for multi-agent routing (hybrid proposed).
- ⚠️ Legal constants (e.g. "14 days" for Finnish KSL, business-day rules) must be checked against the actual law / a lawyer — the source notes present them as fact without citations.

## Knowledge Objects
`KO = (id, subject, predicate, object, embedding, provenance)`, `id = SHA-256(subject || predicate)`.
Signing: RFC 8785 JCS canonicalization → Ed25519. Status: 📐 (good next small module — stdlib + `cryptography`).

## Chronos V3 (System 0/1/2 metacognition)
Entropy-triggered pause → external data fetch (`chronos_nexus`) → Huber-loss denoise (`chronos_logos`) → KO.
Status: 📐. Overlaps with the separate Chronos research agent project.

## Roadmap (suggested order)
1. `ko/` — Knowledge Object builder + JCS + Ed25519 signer, tests.
2. `control_plane/validator.py` — Decision Packet schema + L0–L3 gating.
3. `control_plane/kill_switch.py` — consumes observer CRITICAL, stops container.
4. `cognitive_core/agent.py` — PTAC loop emitting telemetry via `emit()`.
5. Flow-Core FSM (pure Python state table first; SCXML later if needed).
