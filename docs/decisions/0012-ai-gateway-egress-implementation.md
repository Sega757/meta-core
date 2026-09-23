# ADR-0012: AI Gateway as the egress-proxy implementation, with per-request micro-budgets

**Status:** Accepted — extends [ADR-0009](0009-egress-proxy-for-llm-calls.md)

## Context

ADR-0009 established that the Reasoning Plane's egress proxy must whitelist
*which* LLM endpoints `agent.py` can reach. It left the proxy's own runtime
behavior unspecified. Knowing an endpoint is on the whitelist says nothing
about how much a single request is allowed to cost once it gets there — a
whitelist alone doesn't stop a single misbehaving PTAC cycle from generating
an expensive burst of legitimate-looking calls to an approved endpoint.

## Decision

Implement the egress proxy as an LLM-aware **AI Gateway** (a LiteLLM/
Helicone-class component) sitting at the whitelist boundary, adding:

- **Per-request micro-budgets** — a token/cost ceiling on the individual
  request, not just a monthly account-level cap.
- The [ADR-0011](0011-loop-detection-algorithm.md) spend-velocity circuit
  breaker, enforced a second time at the network edge.
- **Semantic response caching** for near-duplicate prompts, so a PTAC cycle
  that re-derives the same Think output doesn't re-pay for it.

## Alternatives considered

| Option | Trade-off |
|---|---|
| Bare reverse-proxy whitelist (ADR-0009 as originally scoped) | Simple, but "reachable" and "affordable" are conflated — nothing stops a reachable endpoint from being called expensively and repeatedly |
| **LLM-aware AI Gateway (chosen)** | Adds a dependency and a config surface, but turns "endpoint reachable" into "endpoint reachable *and* within budget," at the network edge instead of relying solely on the sidecar to catch it mid-run |

## Consequences

- Spend limits are now enforced at **two independent layers** deliberately:
  the gateway (pre-request, network edge) and the Kill-Switch
  ([ADR-0011](0011-loop-detection-algorithm.md), in-run, sidecar). Neither
  replaces the other.
- Adding a new LLM provider or endpoint still requires an explicit whitelist
  update (per ADR-0009), plus a budget policy entry in the gateway config.
- Partially closes the "Kill-Switch numeric ceilings" open question for the
  token-consumption dimension specifically; execution-time, memory, and
  absolute per-run token ceilings are still unset.

See [Reasoning Plane](../architecture/reasoning-plane.md) and
[Deployment Requirements](../deployment/requirements.md).
