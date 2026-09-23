# ADR-0013: Provenance-typed Knowledge Objects

**Status:** Accepted

## Context

The Knowledge Object tuple already carries a `provenance` field —
`KO = (id, subject, predicate, object, embedding, provenance)` — but its
value is unconstrained free text (see
[Data Architecture](../architecture/data-architecture.md)). Nothing at the
schema level distinguishes a fact a real user or verified external source
supplied from one an agent generated during its own reasoning. Any read
path built on top of EGDS — strategy adaptation, training-data export,
engagement analytics — has no mechanical way to exclude agent-authored
facts, which risks the system quietly learning from its own synthetic
output as if it were ground truth.

## Decision

Constrain `provenance` to a fixed enum, enforced at write time by the
Execution Plane (the sole writer, per
[ADR-0002](0002-execution-plane-exclusive-db-access.md)):

- `ORGANIC_USER`
- `SYNTHETIC_AGENT`
- `VERIFIED_EXTERNAL`

Any read path feeding strategy adaptation, model training, or aggregate
analytics **must** filter to `ORGANIC_USER` / `VERIFIED_EXTERNAL`.
`SYNTHETIC_AGENT` rows stay queryable — an agent can still read its own
prior outputs — but are excluded from those views by default.

## Alternatives considered

| Option | Trade-off |
|---|---|
| Free-text `provenance` string (status quo) | Flexible, but gives no mechanical way for an adaptation pipeline to exclude synthetic rows |
| **Fixed enum with mandatory read-side filtering (chosen)** | A three-value enum can't capture nuance like a partially-verified fact without a future migration, but it closes the self-confirming-loop risk the L-E-J-D-A-S "Duty" field is meant to guard against |

## Consequences

- Any new consumer of EGDS must declare which provenance classes it reads.
  A query against the Knowledge DB with no provenance filter should be
  treated as a review flag during code review, not a safe default.
- This is additive to the existing `provenance` field's structure — it does
  not change the `id = SHA-256(subject || predicate)` deduplication logic.

See [Data Architecture](../architecture/data-architecture.md).
