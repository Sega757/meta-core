# Reasoning Plane

The Reasoning Plane is the isolated cognitive layer of META-CORE. It runs
`agent.py` — the `NeocortexSystem1Engine`, built on Python 3.12 and ADK 2.0 —
inside a sandbox that is structurally incapable of touching production state.
It communicates with the rest of the system in exactly two ways: reading the
append-only `event_stream.jsonl`, and emitting a schema-validated Decision
Packet.

## Environment

- **Python 3.12**, strictly required for native `datetime`
  `timezone.utc` handling and the `cryptography` primitives used for Ed25519
  signature verification of inbound AIDL commands.
- Runs inside a **Python virtual environment (venv)**, isolating dependencies
  such as `cryptography` and `numpy`.
- **Blocked raw network sockets** — no path to the open internet.
- **Zero database credentials** — no keys, no connection strings, for
  either SQLite or Redis.

## The PTAC cycle

```mermaid
flowchart TD
    P["1. PERCEIVE\nIngest event_stream.jsonl"] --> T["2. THINK\nSandboxed reasoning\n(no network / DB)"]
    T --> A["3. ACT\nCompile Decision Packet\n(JSON Schema 2020-12)"]
    A --> C["4. CHECK\nRoute to Control Plane sidecar"]
    C -->|fail| P
    C -->|pass| D[Dispatch to Execution Plane]
```

| Phase | Action | Output |
|---|---|---|
| Perceive | Reads current environmental/task context from the append-only event log | Contextual snapshot |
| Think | Processes the payload inside the sandboxed runtime | Logical strategy |
| Act | Compiles the strategy into a strict JSON-Schema 2020-12 structure | Decision Packet |
| Check | Hands the packet to `validator.py` in the Control Plane sidecar | Approve / escalate signal |

## Example Decision Packet

```json
{
  "action": "inventory_correction",
  "parameters": {
    "sku": "META-001",
    "adjustment": -10
  },
  "justification": "Correcting discrepancy noted in event log #882; actual count 40 vs system count 50."
}
```

If a field is missing, malformed, or hallucinated, schema validation rejects
the packet before it ever leaves the sandbox boundary — it never reaches the
database layer.

## Security properties

- **Network/DB air-gap** — a prompt-injection compromise here has nothing to
  exfiltrate and nowhere to write.
- **Command authenticity** — inbound AIDL instructions from the Node.js
  orchestrator are verified with Ed25519 signatures using the `cryptography`
  library.
- **Fact determinism** — Knowledge Objects handled during Think/Act use
  `id = SHA-256(subject || predicate)`; see
  [Data Architecture](data-architecture.md).
- **No self-disable path** — the Validator and Kill-Switch live in a
  separate sidecar container, so nothing the agent does inside its own
  sandbox can touch them. See [Control Plane](control-plane.md).

## Open questions

- Fault-tolerance / retry logic for failed LLM API calls inside the PTAC
  cycle.
- Whether a validation failure's detail is fed back to the agent to drive an
  automatic corrective Perceive-Think-Act retry, or requires external
  intervention.
- The exact token-budgeting logic used when converting raw
  `event_stream.jsonl` lines into a model prompt during Perceive.
- The transport format `agent.py` uses to reach the Node.js AIDL IPC bridge.

See [`docs/open-questions.md`](../open-questions.md) for the full,
consolidated list.
