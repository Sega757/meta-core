# ADR-0015: Claim-level trace evaluation replaces ad-hoc Huber Loss / Z-score filtering

**Status:** Accepted

## Context

`observer.py` is documented as using "Huber Loss, Z-score" to filter
anomalies out of `event_stream.jsonl`, but no threshold values or output
schema were ever specified — two of the standing open questions on the
[Observability Plane](../architecture/observability-plane.md). Separately,
span-level metrics (duration, cost) can tell you *that* a multi-step PTAC
cycle failed, but not *why* — which phase, and which specific claim inside
it, went wrong.

## Decision

Replace the unspecified statistical filter with **span-tree tracing**:
`agent.py` and the Control Plane sidecar each emit one OpenTelemetry-style
span per PTAC phase (Perceive / Think / Act / Check), carrying the prompt,
retrieved context, and Decision Packet payload for that phase. `observer.py`
groups `event_stream.jsonl` lines into these per-run span trees instead of
scanning for statistical outliers, and scores each completed run with two
trace-level metrics:

- **Tool-Call Accuracy** — did the agent select the right tool and
  structure its arguments correctly given the retrieved context?
- **Agent-Goal Accuracy** — was the Decision Packet's stated justification
  actually satisfied by what was retrieved?

## Alternatives considered

| Option | Trade-off |
|---|---|
| Keep Huber Loss / Z-score, just specify the missing thresholds | Smaller incremental change, but a statistical outlier score still can't explain *which claim* in a multi-step reasoning chain broke |
| **Span-tree tracing + trace-level evaluation (chosen)** | Every PTAC phase must now emit a span (more instrumentation work), but a failed run points at the specific phase and claim that broke, not just an aggregate deviation score |

## Consequences

- This also closes the "Trace DAG schema" open question: the trace is a
  standard OpenTelemetry span tree, not a bespoke Mermaid/Graphviz format.
- `event_stream.jsonl` remains the durable, append-only ledger
  ([ADR-0001](0001-decoupled-telemetry-sync.md) is unchanged) — spans are a
  read-side structuring of the same log, not a new write path.
- Tool-Call Accuracy and Agent-Goal Accuracy still need a deployment-chosen
  pass/fail threshold; that threshold is not fixed by this ADR and remains
  an open tuning question.

See [Observability Plane](../architecture/observability-plane.md).
