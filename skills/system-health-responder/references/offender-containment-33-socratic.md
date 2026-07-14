# 33 Socratic Questions — Offender-Containment & the EKO-90 Autonomy Extension

> Operator `/quiesce` 2026-07-14 directive: *"faça novos 33 perguntas socraticas sobre estes aspectos e
> responda"* — the aspects being the new autonomous capabilities (ADR offender-containment, the `claude
> doctor` Phase-1 probe, and handling of related / learned-today / emergent / doubtful / emergency /
> critical items). Grounded in the real 2026-07-14 disk-drain (`uvx …@latest` MCP churn → 926 GB disk to
> ~2.5 GB free) and the operator ADR that authorized disabling/removing a no-source-fix offender. These
> are design-reasoning questions — the answers are the *why* behind the code, kept honest (Mente Tomé).

## A. The ADR and its boundaries

**Q1 — What exactly did the operator authorize, and what did they NOT?**
Authorized: *until a plugin/tool's issue has no fix at the source, it may be disabled and/or removed.* NOT
authorized: acting on suspicion, acting on a source-fixable issue, touching protected tools
(`1password/openclaw/omniroute/claude`), or exposing secrets. The authorization is standing but **scoped
to the no-source-fix predicate** — the predicate is the leash.

**Q2 — Is "no source fix" a permanent state or a snapshot?**
A snapshot. `awslabs/mcp#1400` is "not planned" *today*; upstream could reopen it. So the registry records
a **verified-date** and the evidence URL, and re-validation is a qualitative trigger (a reopened issue →
remove the entry). Acting on stale "wontfix" would be acting on false premises (anti-theater R3).

**Q3 — Disable vs remove — when is each right, and why default to disable?**
Disable is reversible in one command (`plugin enable`) and stops the churn immediately; remove reclaims the
install footprint but costs a reinstall to undo. Default = **disable** (least-action reversible-first,
`harmonic` L3). Remove is the operator's escalation — hence its separate `OFC_ALLOW_UNINSTALL` gate.

**Q4 — Could the ADR be abused to remove a tool that's merely inconvenient, not truly broken?**
That's the exact risk the **evidence gate** exists to block: containment requires a recorded upstream
wontfix, not "I don't like this tool." No registry entry → propose + seed, never act. The gate converts a
broad authorization into a narrow, auditable one.

**Q5 — Who owns the "no source fix" judgment — the agent or the operator?**
Adding a registry entry is a judgment act (research the upstream, confirm no fix) that an agent MAY perform
under `/quiesce`'s "pesquise do que se trata", but it is **auditable and reversible** — the operator can
strike any entry. The agent proposes evidence; the registry is the shared, reviewable record.

**Q6 — Does the ADR authorize acting on the FIRST offense?**
For a *registry-vetted* offender, yes — the evidence (not the count) is the trigger; today's drain was one
event with conclusive upstream proof. For an *un-vetted* producer, no — first sighting → seed + investigate.
Recurrence isn't required when the source-level evidence is already conclusive.

## B. Root cause versus symptom

**Q7 — Why did cleaning the cache fail?**
Because the guardian was fighting a **live producer**: N Claude sessions re-spawning `uvx …@latest`
re-inflated `~/.cache/uv/archive-v0` faster than Tier-1 could `rm` it. Cleaning a cache that is actively
re-filled is symptom-treatment on a loop (`root-cause-first`).

**Q8 — Is disabling the plugin the root, or is `uv @latest` the root?**
Both are layers. The *proximate* producer is the plugin's `uvx …@latest` invocation; the *mechanism* is
`uv @latest` re-resolution + no auto-GC. Disabling the plugin stops THIS producer; the durable class-fix is
avoiding `@latest` (pin / `uv tool install`) + periodic `uv cache prune`. The registry dossier records both.

**Q9 — Would `uv cache prune` alone have prevented the drain?**
No — prune reclaims unreachable objects, but a live producer keeps creating *reachable* fresh envs. Prune is
necessary maintenance (there's no auto-GC) but insufficient against an active `@latest` churner. Hence Tier-A
(prune, stopgap) is explicitly distinguished from Tier-B (contain the producer, root).

**Q10 — What's the difference between a producer and a consumer of disk pressure?**
A consumer accumulates once (a model download, a VM image) — reclaim it and it's gone. A producer *re-creates*
pressure continuously — reclaim is Sisyphean until the producer stops. The collector's new `cache_producer`
leaf is the tripwire that tells the responder "this is producer-driven — prune won't hold."

**Q11 — Is the collector's `cache_producer` leaf measuring the cause or the symptom?**
Both, deliberately: `uv_archive_objects` (symptom footprint, argv-free) + `uvx_latest_procs` (cause
signature). The cause signal (>0 live `@latest` procs while disk is pressured) is what escalates to
containment; the footprint alone only escalates to prune.

## C. Autonomy tiers and rigor

**Q12 — Why does disable get a heavier gate than prune?**
Blast radius. Prune removes regenerable cache objects (self-healing). Disable turns off a capability the
operator installed — reversible, but it changes what the environment can do. More reach → more gates
(`auto-self-harness §1.6`: autonomy is a multiplier of rigor, not a substitute for it).

**Q13 — Why should the launchd responder NOT disable plugins directly?**
Three reasons: (1) the secret-safe contract carries no argv, so the responder can't *name* the offending
plugin; (2) launchd runs unattended with no READY proof and no operator in the loop; (3) disable/remove is
above the Moderate authority EKO-90 chose for the reflex. So the responder seeds; an *active, armed* agent acts.

**Q14 — What proves "READY" for an autonomous containment, concretely?**
The caller sets `OFC_ARM=1 OFC_READY=1` only after proving the standing-autonomy predicate `R1∧R2∧R3∧R4`
(corpus present, capable model, scope-clear ¬HUMAN_DOMAIN, score ≥ HIGH) *and* confirming the offender is
registry-vetted. Absent any → the script fail-safe degrades to dry-run. The flag is never trusted alone.

**Q15 — Is a reversible action (disable) safe to automate? Where's the line?**
Reversibility lowers but doesn't erase risk — a wrongly-disabled tool mid-task still breaks work. The line:
automate reversible-AND-evidence-gated-AND-non-HUMAN_DOMAIN actions; everything else proposes. Disable sits
just over the line *with* the evidence gate; without it, it drops back to propose.

**Q16 — What happens if the arm flags are set but the evidence is absent?**
Nothing is contained. The flags authorize the *mechanism*; the registry authorizes the *target*. A producer
with no registry entry is proposed + seeded even under full arming — the two gates are independent (AND, not OR).

**Q17 — How does this respect "elevate autonomy → elevate rigor"?**
Each stakes tier adds a conjunct: prune (Moderate gate) → disable (+OFC_ARM +evidence) → remove
(+OFC_ALLOW_UNINSTALL). The more the action can hurt, the more must be simultaneously true. Rigor ratchets
up exactly as reach grows.

## D. Evidence, detection, and false positives

**Q18 — How does the responder know WHICH plugin is the offender without reading argv?**
It doesn't — and doesn't try. The responder detects *that* a producer is churning (count signal) and seeds.
The registry (authored by a human/agent that DID inspect) names the plugin. Naming is decoupled from the
secret-safe reflex → no argv-in-contract, no fragile auto-mapping.

**Q19 — What's the false-positive risk of the `uvx @latest` detector?**
Low but real: a benign one-shot `uvx …@latest` could register as a live proc. That's why a bare count only
escalates to *prune* (harmless) or a *seed* (proposal) — never to an autonomous removal. Removal needs the
registry, which only holds proven offenders.

**Q20 — Could a legitimate, needed `uvx @latest` tool be wrongly contained?**
Only if a human/agent wrongly added it to the registry with false "no-source-fix" evidence — a review
failure, not an automation failure. The protected-denylist + the reversible-first default + the audit trail
(`containment.log` restore command) bound the damage of even that mistake.

**Q21 — What if two plugins provide overlapping MCP servers?**
The registry keys on `plugin@marketplace`, not on the MCP server — so containment targets a specific plugin,
avoiding "disable A to stop a server B also provides." If disabling one doesn't stop the churn, the producer
signal persists → re-seed → investigate the second. Deterministic, not guesswork.

**Q22 — How do we prevent the registry from becoming a dumping ground?**
Every entry needs a dossier (mechanism + upstream URL + status + verified-date). No dossier → it's a
watch-list note, not an actionable offender. The gate is *evidence density*, and the changelog makes growth
auditable (`scope-discipline` anti-bloat).

**Q23 — What's the secret-safety cost of extracting the package name from argv?**
Bounded: the containment script extracts only the public `<pkg>@latest` token (a PyPI identifier), never the
full argv, never a `--api-key=` value. The collector avoids argv entirely (object-count primary). A public
package name is not a secret; a token is — and tokens never leave the process (CWE-532).

## E. Emergent, doubtful, critical, emergency

**Q24 — What's an "emergent" item the guardian couldn't foresee, and how is it handled?**
A novel producer class (say a future `npx`-based or `bunx`-based churner). The collector won't have a leaf
for it yet, but the disk-guardian still reclaims + escalates the *symptom*, and the seed reaches an active
agent who researches it (`/quiesce` "pesquise do que se trata") and, if warranted, adds a new registry entry
+ a new collector leaf. Emergent → seed → learn → codify.

**Q25 — What's a "doubtful" item, and why is dry-run+seed the right default for it?**
Doubtful = producer detected but not registry-vetted (evidence uncertain). Dry-run+seed is correct because
acting on doubt is how autonomy hurts; proposing on doubt is how it helps. The default posture is
*propose-under-uncertainty, act-under-evidence* — the whole design's spine.

**Q26 — In a genuine emergency (disk at 0), does the containment gate slow us down dangerously?**
No, because the layers are complementary and fast: the disk-guardian's Tier-1/2 reclaim fires immediately
(space now), Tier-A prune is a fast stopgap, and only the *durable* containment is gated. You never wait on
the gate to get breathing room — the gate governs the root-fix, not the emergency relief.

**Q27 — What distinguishes "critical" (act) from "important" (seed)?**
Critical + autonomous-safe + reversible + evidence-backed → act (prune; armed disable). Critical but
destructive / HUMAN_DOMAIN / un-vetted → seed (security re-enable, plugin removal without evidence). Severity
alone never authorizes action; severity × safety × evidence does.

**Q28 — If the operator is away (unattended), who ratifies a HIGH-stakes removal?**
No one auto-ratifies an un-vetted removal — it stays seeded until an operator or an explicitly-armed agent
handles it. A *vetted* removal can proceed under `OFC_ALLOW_UNINSTALL` + READY, because the operator
pre-ratified that class via the ADR + the registry entry. Unattended ≠ unauthorized, but only within the
pre-ratified evidence boundary.

**Q29 — What's the failure mode if the responder itself is the runaway?**
The engage-lock (mkdir-mutex + verified-stale-steal) prevents two responders double-acting; the renice/prune
are idempotent + bounded; and `claude` is on the protected-denylist so a responder can never contain the
runtime it rides on. The worst case is a no-op, never a self-destruct.

## F. The doctor probe and over-engineering

**Q30 — Why `claude doctor` bare and not `/doctor`?**
`claude doctor` (bare) is read-only, non-interactive, and *only shows* health — the operator's "unattended
show-only". `/doctor` is the in-session interactive fixer (it can change state) → wrong for a 10-min launchd
collector. The collector reports; fixing stays operator/HITL.

**Q31 — What does an unhealthy claude runtime signal, and why is fixing it HITL?**
It signals an install problem (failed auto-update, corrupt version, config issue) that can degrade every
agentic action. Fixing it (`/doctor`, reinstall) can mutate the runtime the responder depends on — squarely
operator/HUMAN_DOMAIN. So the collector surfaces `health != healthy` and the responder seeds; it never
self-repairs its own runtime.

**Q32 — Is running `claude doctor` every 10 min itself a cost/risk?**
Small and bounded: it's timeout-capped (20 s) so it can never hang a cycle, read-only so it can't mutate, and
argv-free in output. The signal value (early detection of a broken agentic runtime + auto-update failures)
exceeds the sub-second probe cost. If it ever proves noisy, its threshold is env-overridable.

**Q33 — How do we know the whole design isn't over-engineering (Gordian)?**
Because it *reuses* rather than reinvents: the collector's existing branch/roll-up shape, the responder's
existing seed/lock/notify, the disk-guardian's escalate pattern, `uv cache prune` (native), `claude plugin`
(native). The only genuinely-new artifact is the containment executor + its evidence registry — and both
exist to answer a *real, lived* failure (the 2026-07-14 drain), not a hypothetical. Real problem, minimal
new machinery, disarmed-by-default → not theater.
