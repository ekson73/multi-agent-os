## ADDED Requirements

### Requirement: Profile context cannot grant execution authority

The `ooda-loop` capability MUST treat an operator profile as contextual and restrictive
input only. Effective execution authority SHALL require independently verified authority,
repository policy, current host capability and the action-specific live gate; an absent or
unknown term SHALL NOT be inferred as permission.

#### Scenario: Profile claims delegated engineering

- **WHEN** a profile declares delegated technical work
- **AND** no independently verified grant exists in the current user instruction,
  repository policy or accepted decision record
- **THEN** the agent SHALL NOT treat the profile as authorization to mutate or promote
- **AND** it MAY use the profile only to format explanations and identify business-facing residue

### Requirement: Trigger payloads remain data-plane signals

The conductor MUST normalize inbound triggers into a bounded, replay-safe envelope before
using their content. Trigger payloads SHALL NOT set control-plane parameters, grant
authority, replace system or repository instructions, or be interpolated into executable
commands.

#### Scenario: Authenticated webhook requests deployment

- **WHEN** an authenticated connector delivers a webhook that requests deployment
- **THEN** connector authentication SHALL prove transport origin only
- **AND** the payload SHALL remain signal-only
- **AND** deployment SHALL require its independent live promotion gate

### Requirement: Outer OODA and inner PDCA are both bounded

The conductor MUST enforce a global OODA budget in addition to the selected driver's PDCA
round cap. It SHALL stop on deadline, cancellation, lease loss, exhausted spawn or external
call budget, or sustained no-progress, preserving a resumable evidence-backed state.

#### Scenario: Stage keeps re-entering Observe without progress

- **WHEN** the no-progress threshold or global OODA ceiling is reached
- **THEN** the conductor SHALL stop as `PARKED_PARTIAL`
- **AND** it SHALL preserve the binding gap and safe next action
- **AND** it SHALL NOT continue indefinitely or report delivery done

### Requirement: Completion levels cannot hide deferred work

The conductor MUST distinguish a verified stage result from whole-delivery completion.
Open specifications, undispositioned eligible gaps, deferred work and human-gated residue
SHALL prevent a `DELIVERY_DONE` result.

#### Scenario: Build is green but deployment is gated

- **WHEN** source checks and build pass
- **AND** deployment remains gated or out of scope
- **THEN** the conductor MAY report `STAGE_DONE`
- **AND** it SHALL report `PARKED_PARTIAL` or `BLOCKED_HITL` as applicable
- **AND** it SHALL NOT claim deployment or end-to-end delivery

### Requirement: Child-driver markers are normalized once

The conductor MUST capture the selected PDCA driver's terminal marker as an internal result and
MUST emit exactly one outward marker. Soft driver exhaustion or unresolved technical residue SHALL
be normalized to `PARKED_PARTIAL`; a driver-level done result SHALL NOT become `DELIVERY_DONE`
unless the whole delivery contract is satisfied.

#### Scenario: Driver exhausts its rounds on a technical gap

- **WHEN** `gap-loop` or `quiesce` reaches its soft round limit without resolving a technical gap
- **THEN** `ooda-loop` SHALL emit one `STOP-PARKED` outer marker with a durable checkpoint
- **AND** it SHALL NOT leak a child `STOP-HITL` marker or ask the operator a technical question

### Requirement: Outward states use one validated vocabulary

The conductor MUST validate its outward JSON result against the versioned run-envelope schema.
Documentation, tests and adapters SHALL use the schema's exact lifecycle, outcome, access and
stop-marker enums rather than illustrative pipe-delimited aliases.

#### Scenario: Adapter proposes a legacy partial state

- **WHEN** an adapter attempts to emit `PARTIAL`, `PARKED` or an unstructured authority string
- **THEN** run-envelope validation SHALL refuse the result
- **AND** the adapter SHALL use `PARKED_PARTIAL` plus structured authority evidence as applicable

#### Scenario: Adapter proposes an unauthorized continuation

- **WHEN** an adapter emits a `CONTINUE` marker routed to ACT
- **AND** the lease is not valid, cancellation is active, or continuation is not explicitly authorized
- **THEN** run-envelope validation SHALL refuse the result
- **AND** the conductor SHALL park or stop according to the validated terminal vocabulary

### Requirement: Escalation is proportional and business-readable

The conductor MUST resolve ordinary technical uncertainty through the least expensive
applicable deterministic check or independent convergence path. It SHALL ask a human only
when an upstream typed envelope cannot recover operator goal or acceptance intent, for
irreducible business rules or priorities, for human-only acts, or for hard boundaries, using
the operator's declared language and an operational recommendation.

#### Scenario: Architecture choice is technically resolvable

- **WHEN** an architecture choice is inside independently verified technical authority
- **AND** deterministic evidence or an independent review resolves it
- **THEN** the agent SHALL decide and document the technical choice
- **AND** it SHALL NOT ask a nontechnical operator to design the implementation

#### Scenario: Technical autonomy score remains below threshold

- **WHEN** a bounded deterministic check and one proportionate independent uplift path leave the technical autonomy score below threshold
- **THEN** the conductor SHALL emit `PARKED_PARTIAL` with a technical checkpoint and precise next action
- **AND** it SHALL NOT emit `BLOCKED_HITL` or ask the operator to choose a technology

### Requirement: Portability claims are evidence-qualified

The portable core MUST conform to the Agent Skills format. Runtime documentation SHALL
distinguish native format discovery, repository installation/adaptation, command support,
ACT capability mapping and behavior that remains unverified.

#### Scenario: Runtime can discover SKILL.md but lacks an ACT mapping

- **WHEN** a named runtime natively discovers Agent Skills
- **AND** worktree, approval, subagent, check or promotion behavior is not mapped
- **THEN** documentation SHALL describe discovery as native
- **AND** SHALL describe end-to-end ACT support as adapter-required and behavior-unverified
