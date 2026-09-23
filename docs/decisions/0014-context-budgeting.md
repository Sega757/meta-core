# ADR-0014: Fixed context-token budget bands for the Perceive phase

**Status:** Accepted

## Context

The [Reasoning Plane](../architecture/reasoning-plane.md)'s Perceive step
ingests `event_stream.jsonl` to build the Think-phase prompt, but the exact
token-budgeting logic for that conversion was an open question. Unbounded
context assembly (full history + all tool descriptions + all retrieved
facts on every call) both inflates per-call cost and, independent of cost,
degrades reasoning quality once the window fills with low-relevance
material — the model loses track of the facts that actually matter.

## Decision

Partition the context window into fixed percentage bands, enforced when
`agent.py` assembles the Think-phase prompt:

| Component | Budget | Purpose |
|---|---|---|
| System prompt | 10–15% | Static rules/persona only — no per-cycle content |
| Tool descriptions | 15–20% | Caps simultaneously-exposed tools (~5–15); route the rest through hierarchical tool discovery if exceeded |
| Retrieved context (`event_stream.jsonl` excerpt, EGDS facts) | 30–40% | The Truth Anchor grounding for this cycle |
| History / memory | 20–30% | Truncated, oldest-first; lazily loaded |
| Generation buffer | 10–15% | Reserved so the Decision Packet JSON isn't cut off mid-generation |

## Alternatives considered

| Option | Trade-off |
|---|---|
| Full conversation replay every Think call (unspecified status quo) | Simple to implement, but has no ceiling on cost or on attention degradation as history grows |
| **Fixed percentage bands (chosen)** | Can occasionally starve a genuinely context-heavy cycle, but gives Perceive a concrete, closed-form budgeting rule instead of none |

## Consequences

- `agent.py`'s Perceive step needs a token-counting pass before Think
  fires, per component.
- A band overflow in any one category should log a truncation event to
  `event_stream.jsonl` rather than fail silently — this keeps the "Clean
  Trail" complete about *what the model actually saw*, not just what it
  decided.
- This closes the "context token budgeting" open question.

See [Reasoning Plane](../architecture/reasoning-plane.md).
