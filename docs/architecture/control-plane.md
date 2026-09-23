# Control Plane

The Control Plane is META-CORE's safety gateway. It runs **out-of-process**,
in an isolated sidecar container, specifically so that a compromised
Reasoning Plane cannot reach into it and disable its own guardrails. It has
two modules: the **Validator** (evaluates *what* the agent wants to do) and
the **AI Kill-Switch** (monitors *how* the agent is behaving).

## Why a sidecar, not in-process

| | In-process validation | Out-of-process sidecar (chosen) |
|---|---|---|
| Latency | Sub-millisecond | Minor IPC/serialization overhead |
| Security | A jailbroken model can potentially patch validator memory to force "pass" | Compromise of the reasoning sandbox has no path to the validator's memory space |
| Verdict | Rejected — see [ADR-0003](../decisions/0003-sidecar-isolated-safety-modules.md) | Adopted |

## Validator (`validator.py`)

Evaluates every Decision Packet against the six-field **L-E-J-D-A-S**
safety framework and assigns an **L0–L3 escalation level**. Full detail:
[`docs/security/l-e-j-d-a-s-framework.md`](../security/l-e-j-d-a-s-framework.md).

## AI Kill-Switch

Monitors runtime telemetry and forces an emergency stop when a bound is
breached:

| Signal | What it protects against |
|---|---|
| Execution time | Runaway / hung reasoning cycles |
| Memory footprint | Host resource exhaustion |
| Token consumption | Uncontrolled LLM billing |
| Cyclic / recursive loops | Infinite logical loops, redundant tool calls |

The Kill-Switch executes independently of the Reasoning Plane's health — it
can terminate the sandbox process even if the Python interpreter is
100% CPU-saturated or otherwise unresponsive.

The cyclic/recursive-loop signal specifically is implemented as a
pre-dispatch check — a monotonic step counter, a SHA-256 semantic-hash
repeat-call guard, and a rolling spend-velocity circuit breaker — evaluated
*before* a tool call is dispatched rather than diagnosed after the fact.
See [ADR-0011](../decisions/0011-loop-detection-algorithm.md). Token
consumption is additionally bounded a layer earlier, at the egress proxy
itself — see [ADR-0012](../decisions/0012-ai-gateway-egress-implementation.md).

## Validation gate in the PTAC flow

```mermaid
flowchart TD
    A["Reasoning Plane: ACT\n(Decision Packet compiled)"] --> B[["ISOLATION BOUNDARY\nsandbox exit"]]
    B --> C["Control Plane: Validator\nL-E-J-D-A-S check"]
    C -->|PASS / L0| D[Dispatch to Execution Plane]
    C -->|L1| E[Log + agent self-correction feedback]
    C -->|L2| F[Halt queue execution,\nawait human authorization]
    C -->|L3| G[AI Kill-Switch:\nterminate + rollback]
```

## Security properties

- **Prompt-injection containment** — safety rules cannot be reflected on or
  memory-patched from inside the reasoning sandbox.
- **Malformed payload defense** — non-conforming Decision Packets are
  dropped at the boundary, never reaching the database.
- **Escalation isolation** — L0–L3 tiers let the system respond
  proportionally instead of hard-crashing on every minor violation.
- **Fail-secure default** — if the sidecar loses its link to the Execution
  Plane, dispatches are blocked by default (architectural extrapolation —
  not yet confirmed in source material).

## Open questions

- The concrete evaluation logic and numeric thresholds distinguishing L0,
  L1, L2, and L3.
- The transport protocol (HTTP, Unix socket, gRPC) carrying Decision Packets
  from `agent.py` to the sidecar.
- The signal used to terminate the sandboxed agent process (`SIGKILL`,
  `SIGTERM`, or a webhook-style stop request).
- Rollback/state-recovery behavior for transactions cut off mid-flight by an
  L3 kill.
- ~~Active loop-detection algorithm~~ — resolved by
  [ADR-0011](../decisions/0011-loop-detection-algorithm.md).
- Kill-Switch numeric ceilings for execution time, memory, and absolute
  per-run token count remain unset — ADR-0011 and
  [ADR-0012](../decisions/0012-ai-gateway-egress-implementation.md) only
  fix the loop-repetition and spend-velocity dimensions.

See [`docs/open-questions.md`](../open-questions.md) for the full list.
