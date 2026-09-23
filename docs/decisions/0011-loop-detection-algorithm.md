# ADR-0011: Semantic-hash and spend-velocity loop detection for the Kill-Switch

**Status:** Accepted

## Context

The [Control Plane](../architecture/control-plane.md) documents *that* the
AI Kill-Switch monitors for "cyclic / recursive loops," but not *how* it
tells a live runtime loop apart from legitimate iteration — this was an open
question. `observer.py` already does passive, after-the-fact loop detection
by building a Trace DAG from `event_stream.jsonl`, but that only diagnoses a
loop once it has already happened. The Kill-Switch needs a cheap, in-line
check it can run *before* a tool call is dispatched, not a forensic one.

## Decision

Before each tool call reaches an external API or LLM provider, evaluate
three signals in the sidecar's dispatch gate:

1. **Monotonic step counter** — a hard `max_steps` ceiling per agent run.
2. **Semantic-repetition guard** — hash `(tool_name, sorted(tool_args))`
   with SHA-256; a repeat hash within the same run interdicts immediately,
   without waiting for the step budget to run out.
3. **Spend-velocity circuit breaker** — a rolling 60-second window of
   estimated call cost; if the sum exceeds a configured `$/min` ceiling,
   halt regardless of step count.

```python
class ExecutionCircuitBreaker:
    def __init__(self, max_steps: int, max_velocity_usd_per_min: float):
        self.max_steps = max_steps
        self.max_velocity = max_velocity_usd_per_min
        self.history: list[dict] = []
        self.seen_call_hashes: set[str] = set()

    def validate_step(self, step_index, tool_name, tool_args, estimated_cost):
        if step_index >= self.max_steps:
            raise KillSwitchTrigger("step ceiling exceeded")

        call_hash = sha256(f"{tool_name}:{sorted(tool_args.items())}")
        if call_hash in self.seen_call_hashes:
            raise KillSwitchTrigger(f"repeated call: {tool_name}")
        self.seen_call_hashes.add(call_hash)

        now = time.time()
        self.history.append({"time": now, "cost": estimated_cost})
        recent = sum(h["cost"] for h in self.history if now - h["time"] <= 60.0)
        if recent > self.max_velocity:
            raise KillSwitchTrigger(f"spend velocity {recent:.2f}/min exceeded")
```

## Alternatives considered

| Option | Trade-off |
|---|---|
| Reactive-only (trip after a daily/monthly spend threshold) | Fails to catch a runaway loop early — by the time the threshold trips, the budget is already gone |
| Global thread/process timeout only | Catches a hung process, but not a *still-progressing* infinite tool-call loop |
| **Semantic-hash + step-counter + velocity breaker (chosen)** | Small per-run state overhead (a hash set + a rolling cost window), but stops both duplicate-call loops and spend spikes before they compound |

## Consequences

- The sidecar (or a thin pre-dispatch guard in front of it) now keeps small
  per-run state — a call-signature set and a rolling cost window. This state
  resets each run; it is not part of the Decision Packet schema.
- `max_steps` and the `$/min` velocity ceiling are deployment-configurable,
  not fixed constants — see the still-open numeric-ceiling question below.
- This closes the "active loop-detection algorithm" gap in
  [`docs/open-questions.md`](../open-questions.md); it does **not** set the
  execution-time, memory, or absolute token ceilings the Kill-Switch also
  needs — those remain open.

See [Control Plane](../architecture/control-plane.md).
