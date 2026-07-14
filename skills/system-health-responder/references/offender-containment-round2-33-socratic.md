# Offender-Containment — Round-2 33 Socratic Q&A (operational / detection / false-positive / HITL-boundary)

> **Round-2 (2026-07-14), non-duplicate by design.** Round-1's 33 (`offender-containment-33-socratic.md`)
> covered *design*: ADR boundaries, tiers, rigor, evidence-gate rationale. This round-2 set covers what only
> surfaced by **running the recon**: sibling-offender falsification, transient-vs-persistent producers,
> attribution, the warn-residue HITL boundary, unknown/emergent-offender handling, and round-convergence
> anti-theater. Every answer is grounded in the round-2 recon (not hypotheticals — Mente Tomé).

## Group G — Sibling offenders & false-positive containment (Q1–6)

**Q1. Round-1 contained `deploy-on-aws`. The natural next question: do its ~20 sibling AWS plugins carry the same `uvx …@latest` servers?**
Tested and **FALSIFIED**. A manifest sweep of all four AWS/deploy marketplaces found `deploy-on-aws` was the *unique* carrier. The `uvx`/`awslabs` strings in siblings are docs, `uvx black`/`ruff` formatter hooks (pinned, not `@latest` MCP), lockfiles, and `serena`'s `.mcp.json`. The offender was one plugin, not a family.

**Q2. Why was falsifying that hypothesis the single most valuable round-2 act?**
Because the seductive round-2 move was to "harden" by mass-adding registry entries for the aws-* family and containing them. That would have (a) disabled plugins the operator may actively use, (b) violated the evidence-gate (no vetted upstream wontfix for them — they aren't even producers), (c) been textbook governance theater. Skopos Gate-0 recon converted a plausible-but-wrong action into a *recorded non-action*.

**Q3. What structurally prevented a false-positive containment even if the recon had been skipped?**
The **evidence-gate**: `offender-containment.sh` only acts on plugins in `no-source-fix-registry.md` with a confirmed upstream wontfix. The aws-* siblings were never in it. The gate is precisely a false-positive firewall — "no recorded evidence → propose + seed, never contain."

**Q4. Should the falsification be *recorded*, or just acted on silently?**
Recorded — in the registry's "Round-2 falsifications" section. An amnesic agent next month, seeing 20 aws-* plugins near a disk incident, would re-run the same investigation (wasted cycles) or worse, wrongly contain them. The recorded negative finding is a durable anti-false-positive (the `audit-protocols §1.1` "absence-conclusion needs recording" principle applied to *non-offenders*).

**Q5. Is "record a negative finding" itself over-documentation (Gordian)?**
No — it is proportionate: ~3 bullets that prevent a high-cost future error (disabling the operator's plugins). The Gordian test is effort-vs-outcome; a few lines that prevent a wrong containment pass it. Over-documentation would be a 5-page analysis of each of the 20 plugins; a one-line "family cleared 2026-07-14" is right-sized.

**Q6. The `deploy-on-aws` cache dir still exists after uninstall — is that a residual offender?**
No. It is an inert cache-orphan (README + plugin.json, no live MCP config) — the known Claude-Code plugin-cache-orphan pattern, GC'd by native `.orphaned_at` 7-day sweep. It does not re-inflate the uv cache. Hand-`rm`-ing plugin cache is riskier than letting native GC run → **no action**, just a note so it isn't mistaken for a re-drain.

## Group H — Transient vs persistent producers (Q7–12)

**Q7. The recon saw a live `uvx @latest` producer (pid 28935); seconds later it was gone. What model does that confirm?**
The **spawn-do-exit** model: `uvx …@latest` MCP servers are short-lived — they spawn, re-resolve from PyPI (writing a fresh env to `archive-v0`), serve, and exit. The damage is the *cache write per spawn* × N sessions, not a sitting runaway. So the disk drain is death-by-a-thousand-transient-spawns, not one fat process.

**Q8. Why does a transient producer make `renice`/kill useless as a lever?**
The process is gone before you could act on it. You cannot deprioritize or kill what no longer exists. The lever against a transient producer is **at the source** (disable the plugin that keeps re-spawning it) or **the cache** (`uv cache prune`), never the process. This is why round-1's fix was disable-the-plugin, not kill-the-proc.

**Q9. Counting `uvx_latest_procs` catches a spike, but the pid vanished before it could be named. What capability gap did that expose?**
**Attribution.** A count says "a producer exists"; it does not say *which*. Round-2 added `uvx_latest_producers` — the collector grabs the live producer's `<pkg>@latest` token(s) in the same snapshot as the count, so an emergent offender is named while it's still alive.

**Q10. Why record the package token in the *contract* rather than log it separately?**
The contract is the single searchable source of truth every agent reads (jq/yq). Putting attribution there means the responder, a future session, or the operator can `jq '.system.branches.agentic_tools.leaves.cache_producer.uvx_latest_producers'` and immediately know the offender's name — no separate log to correlate, no pid to chase.

**Q11. A transient spawn might be gone even between the count and the `ps`. How is that handled?**
Gracefully: `ps -o args= -p <pids>` prints nothing for a vanished pid → the grammar grep matches nothing → `uvx_latest_producers` is `null`. The count and the attribution are independent best-efforts; a null attribution alongside a non-zero count honestly means "a producer existed but vanished before naming" — no fabrication (anti-theater R3).

**Q12. Does attribution change any *action*, or is it observe-only?**
Observe-only in round-2 (it names, it does not contain). But it is the *input* to a future action: a named, re-emergent producer can be looked up in the registry, or if un-vetted, seeded to the operator with its actual name ("`foo.bar-mcp@latest` is re-inflating the cache — investigate upstream"). Naming precedes any evidence-gated containment.

## Group I — The warn residue & the HITL boundary (Q13–18)

**Q13. The contract shows `system.status=warn root_fail=cpu` (`fseventsd` 80%). Is that an EKO-90 problem to auto-fix?**
No. `fseventsd` (macOS FSEvents daemon) at 80% is a *symptom* of heavy filesystem churn (the cache thrash + the balloon-rm). It is macOS's own daemon — not killable, not the tool's to renice (system-critical). Root-cause-first: the cause was the producer churn (now drained); `fseventsd` settles on its own. → seed/note, no action.

**Q14. The contract also shows `security.firewall=disabled` and `malware.xprotect_freshness=47 days`. Why are these NOT auto-fixed?**
They are HITL by the safety-matrix: re-enabling the firewall is a System-Settings security-control change; updating XProtect is an OS security update. Both are operator-domain (`[C17]` §2) — the responder **seeds + notifies**, never flips a security control autonomously. Round-2's job is to *surface* them prominently, not to touch them.

**Q15. Are firewall-off and stale-XProtect "emergent" items the tool should escalate loudly?**
Yes — they are genuine, *persistent* security-posture gaps (unlike the transient cpu spike). They're exactly the "itens dúvidoso/críticos" the operator asked the tool to surface. The right handling: a prominent operator-facing line + the standing NEEDS-AGENT seed (already queued) — HITL, not auto-heal.

**Q16. A stale `NEEDS-AGENT` seed from 07-14 00:32 lists the same firewall/xprotect items plus a `claude` pid at 198% CPU. How should round-2 treat it?**
Drain it (Taxis no-silent-drop): the security/malware items are *still true* → carry them forward to the operator. The cpu/process items are *stale* (that snapshot's `claude` pid is long gone; re-measured shows `fseventsd`). So: partially-drain — persist the still-valid HITL items, mark the transient ones re-measured. Never leave a queued seed rotting.

**Q17. Why not auto-renice `fseventsd` since it's the top consumer?**
Two reasons: (1) it's a macOS-critical daemon — deprioritizing it harms the file-event pipeline the whole OS/Finder depends on; the PROC-guard errs conservative. (2) It's a *symptom*; renicing it treats the symptom while the cause (producer churn) is what mattered — and that's already fixed. Root-cause-first says don't renice a symptom.

**Q18. What is the honest DoD-recovery status given a `warn` contract?**
The **EKO-90/disk-recovery** DoD is MET (disk 136 GB, producers 0, offender contained, guardian live). The `warn` is on *orthogonal* branches (macOS security posture + a transient cpu blip) that were never in EKO-90's scope. Conflating them would be moving the goalposts. The tool correctly reports warn + seeds the HITL residue — that IS the design working.

## Group J — Attribution capability design (Q19–24)

**Q19. Recording a producer's argv token in a world-readable contract — how is that not a secret leak?**
By **grammar, not vigilance.** Only tokens matching `^[a-zA-Z0-9][a-zA-Z0-9._-]*@latest$` are accepted. A `--api-key=…@latest` starts with `-` → rejected; an `X=secret@latest` contains `=` → rejected; a path contains `/` → rejected. A valid PyPI package spec (`awslabs.aws-api-mcp-server@latest`) is the *only* shape that passes. The extraction is structurally incapable of capturing a flag or a value.

**Q20. Was that grammar claim tested or asserted?**
Tested (Mente Tomé). A unit-check fed `--api-key=deadbeef@latest`, `X=secret@latest`, `-p`, `/usr/bin/uvx`, and two real package tokens through the exact regex — only the two package tokens were ACCEPTED, all four flag/value/path cases rejected. The secret-safety is proven, not hoped.

**Q21. Why `@latest`-only, not every package token?**
Because `@latest` is the offender signature — it's the un-pinned, re-resolve-every-spawn form that causes the uv-cache churn. A pinned `pkg==1.2.3` re-uses its cached env (no churn). Attribution deliberately narrows to the churny form: it names *offenders*, not every uvx invocation (which would be noise).

**Q22. Why cap at 5 tokens and dedup?**
Bound the field (anti-bloat): even under heavy churn a handful of distinct offender packages is the real cardinality; `sort -u | head -5` keeps the contract small + deterministic. A pathological 500-producer moment would still record the top few names — enough to identify the class.

**Q23. Does attribution add latency/risk to the every-10-min collector?**
Negligible + bounded: it only runs `ps` when `uvx_latest_procs > 0` (usually 0 → skipped entirely), and the `ps` is `run_bounded 5` (timeout-guarded). No new dependency, read-only, secret-safe. It rides the existing producer probe.

**Q24. Is a `null` attribution ever misleading?**
No — `null` honestly means "no live `@latest` producer named this cycle" (either none exist, or one vanished before `ps`). It never fabricates a name. Paired with the count, `procs>0 ∧ producers=null` is itself informative: "a transient spawn happened" — the exact 28935 case.

## Group K — Unknown / emergent / doubtful / critical / emergency items (Q25–29)

**Q25. The operator wants the tool to handle "itens emergentes, dúvidoso, emergência, críticos." How does the tool handle an UNKNOWN emergent offender (not `deploy-on-aws`)?**
Detection → attribution → evidence-gate → seed. The `cache_producer` tripwire fires on any `uvx …@latest` under disk pressure; attribution names it; the registry check decides — *vetted* → containable (armed), *un-vetted* → propose + seed the operator to research the upstream ("pesquise do que se trata"). An unknown offender never gets silently contained (no evidence) nor silently ignored (it's seeded).

**Q26. "Doubtful" — what if it's unclear whether a detected producer is actually harmful?**
Default to non-action + surface. The tool proposes (dry-run) and seeds; it does not contain on doubt. Containment requires *recorded* evidence (a vetted wontfix). Doubt resolves toward the reversible-safe side: observe + ask, never disable-on-suspicion. This is the fail-safe-when-uncertain posture (`auto-self-harness §1.6`: under granted autonomy, doubt → HOLD-not-force).

**Q27. "Emergency / critical" — does the tool ever take a stronger autonomous action for a real crisis?**
Only within the reversible, non-destructive envelope: `uv cache prune` (LOW) and, if armed + vetted + present, `disable` (MEDIUM, reversible). It never escalates to kill/quarantine/uninstall autonomously — those stay HITL even in an emergency (per the ⛔ guardrails + standing-autonomy R3). A true emergency triggers *stop-immediately + notify + persist*, not a bigger hammer.

**Q28. What distinguishes an "emergent" item the tool acts on from one it only seeds?**
The reversibility + evidence axes. Reversible + vetted-evidence + within Moderate/armed scope → act (prune/disable). Irreversible OR HUMAN_DOMAIN (security control, OS update, kill) OR un-vetted → seed. The disk-producer class is the sweet spot the tool acts on; firewall/xprotect/kill are the seed class.

**Q29. Could the operator's "críticos" ever mean the tool should mass-disable to stop-bleeding?**
No — round-2 proved the opposite. Mass-disable (the aws-* family) would have been a *false* stop-bleeding (they weren't producing) that damaged the operator's setup. Stop-bleeding is *targeted at the confirmed offender*, not a shotgun. Precision under pressure > breadth under pressure.

## Group L — Round convergence & anti-theater (Q30–33)

**Q30. Round-1 fully shipped + merged the goal. When the operator re-fires the identical directive as "round-2," what makes round-2 legitimate rather than theater?**
Legitimacy = genuinely-new substance surfaced by *doing* (not re-doing). Round-2's recon found real new material: the sibling-falsification, a live transient producer, the attribution gap, 2 persistent HITL security findings, a stale seed. Re-generating round-1's artifacts would be theater; addressing what the recon newly revealed is convergence.

**Q31. How was round-2 kept from bloating to "match" round-1's size?**
By Gordian scoping to what's real: one small collector capability (attribution), one registry finding (falsification), one seed-drain, one non-duplicate 33-Q set, and surfacing 2 HITL items. No new offenders contained (none exist), no aws-* registry entries (falsified), no code where a note suffices. Size follows substance, not symmetry.

**Q32. Is the quiescence predicate satisfied after round-2?**
Yes: EKO-90 scope has no open PR once round-2 merges, disk-recovery DoD holds, no un-actioned offender remains (the residue is HITL-seeded, which is the terminal state for operator-domain items). The system is quiescent — the honest terminal condition, not a manufactured "keep going."

**Q33. What is the single durable lesson of round-2 for the next amnesic agent?**
*Recon before hardening.* The obvious round-2 hardening (contain the offender's siblings) was wrong; only running the probe revealed the offender was singular and the siblings innocent. A recorded falsification is as valuable as a recorded fix — it prevents the next agent from confidently doing the wrong thing. Observe, then act — or, here, observe, then *deliberately don't*.
