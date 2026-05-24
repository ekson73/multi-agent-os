# Product matrix — capability classes per stage (vendor-neutral)

The AI-native startup runs on three **capability classes**. The framework is
provider-agnostic; the *reference* column names Claude products as the canonical
implementation, but any AAIF-compatible tool that fills the class works.

| Capability class | Mental model | Reference tool |
|---|---|---|
| **Conversational research** | On-call expert for every domain — deep research, document drafting, strategic thinking partner (devil's advocate, pre-mortems, scenarios) | Claude (Chat) |
| **Agentic coding** | The engineer who's always available and never blocked — generate, test, debug, refactor production code | Claude Code |
| **Workflow automation** | On-demand ops team — recurring tasks run themselves; integrates with the tools the company already uses | Claude Cowork |

## Which class leads at each stage

| Stage | Primary class | Secondary | Why |
|---|---|---|---|
| **Idea** | Conversational research | — | Research, competitive synthesis, customer-discovery logistics. Code comes *after* validation. |
| **MVP** | Agentic coding | Conversational research; light automation | Build the focused product; research defines architecture/scope/metrics first; automation runs the feedback loop. |
| **Launch** | All three, compounding | — | Coding remediates tech debt + hardens infra; automation removes founder-as-bottleneck; research designs the processes. Each tool's output is another's input. |
| **Scale** | All three, org-wide | — | Coding builds enterprise-grade infra + integrations (moat); automation runs the operating layer + GTM execution; research drives narrative, GTM strategy, and domain-knowledge capture. |

## Stage-by-stage usage notes

- **Idea** — Use research to read many user-interview transcripts, synthesize a
  competitive landscape, and build target-interview lists from public signals. Do
  **not** open the coding tool yet.
- **MVP** — Define architecture + scope **before** coding; persist them in a context
  file (e.g., `CLAUDE.md`) so each session shares one mental model. Run a first-pass
  security review before any real user touches the product. Use automation for
  discovery/feedback logistics (outreach, scheduling, triage, weekly synthesis) —
  but keep a human interpreting nuanced feedback.
- **Launch** — Coding runs an architectural audit + targeted refactor + test-coverage
  expansion, and surfaces SOC 2 / GDPR / HIPAA-relevant issues. Automation runs the
  product-management operating system (sprint cadence, bug triage, weekly metrics).
- **Scale** — Coding hardens to enterprise reliability (logging, monitoring, incident
  response, SLAs) and builds integrations/APIs/SDKs (workflow lock-in). Automation
  runs enterprise support + GTM execution. Research turns founder domain expertise
  into reusable **Skills** and a data-moat narrative.

## Vendor-neutrality guard-rail

Keep each capability class behind a provider-agnostic seam. A single vendor's
outage, deprecation, or price change must never paralyze the company — the lean
startup's leverage depends on the *capabilities*, not a specific brand.
