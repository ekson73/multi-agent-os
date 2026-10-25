---
name: virtuous-spiral
description: Run a spiral, event-driven virtuous delivery cycle (forward-1 delivers a node downward, backward traces every deliverable up to a motivation and prunes theater, forward-2 repeats only the missing deliverables one level up) over a node tree (project, motivations, criteria, tasks, steps, AI sessions, subagents), with a five-lens introspective retro, authorized bounded self-evolution and auto-persisted records. Use when a team of agents wants a human-out-of-the-loop productivity loop, when a set of deliveries or actions ends (a PR, a BRIEF, a session) and the next round must learn from it, when a child project must declare variations of this parent, or when the user says "virtuous spiral", "espiral virtuosa" or "ciclo virtuoso HOTL". Hard-floor items (credentials, new spend, external sends, irreversible actions, security policy, power or access expansion, merges without an approvers registry) always stay with the human owner.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.3.1"
  scope: cross-vendor
  family: orchestration-convergence
  cross_link_slug: virtuous-spiral
  dogfood_status: pending-first-cycle
  piso_sha256: "1d8792727ac29521b05d51f106570f36a1e25a4aa0175f5a7a62a8e5957b7d99"
---

# Virtuous Spiral HOTL (generic parent skill, SSOT)

Public, generic text: no names of agents or people, no ticket or message ids, no local paths, e-mails or third-party data. Roles are lenses: ORQ (orchestrator and cycle owner), AUD (audit and review opinion "C"), QA (verification), CUSTOS (cost measurer). The aliases ORQ, AUD, QA, CUSTOS are identifiers and stay as written. "Human decider" is the project owner. Status: PROPOSAL until merged under the repository policy with a C opinion on the head.
Precedence: the project's canonical policy > this parent > child. Doubt about a classification = floor. Every normative number lives only in the table of the "Inviolable floor" section; the rest of the text points to it.

## 1. Goal
Deliver at professional quality with the human out of the operational path (HOTL, Human Out The Loop): the human gives direction, holds the veto and decides the Inviolable floor (own section below). Each round delivers, learns and records where the next one reads. Fundamental property: round N+1 starts by reading what round N recorded.

## 2. How to adapt (generic parent, case by case)
This parent is generic: each case adapts and specifies it by common sense, declaring only the child's variations (§14). Common sense = pick the smallest version that meets the goal (anti-over-engineering). Adapting never loosens the Inviolable floor or the parent's DoD. When unsure between adapting and following to the letter: follow to the letter and record the doubt in the retro.

## 3. Node model (N-Tree, one cycle per node)
Levels: L0 project; L1 motivations (originating, foundational, generational agentic DNA, primary, secondary, auxiliary); L2 criteria (DoR, DoD, goals, targets, deliverables, expected effects); L3 tasks; L4 steps; L5 ai-session; L6 subagents. Only open nodes exist; a one-step, no-risk node merges into its parent.
| Field (closed keys) | Rule |
|---|---|
| id, level, parent | verifiable chain by link; without `parent` the node is an orphan |
| anchor | id of an existing L1 motivation; creating a new motivation is a human decision |
| owner, class | who answers; class 1 or class 2 (Floor, "Class and validity") |
| DoR | entry: goal, acceptance criterion, risk, owner, dependencies, ceiling |
| DoD | exit: proofs (SHA, run, link), green checks, C opinion when required |
| goal, target | qualitative direction; number and deadline with a metric source (§13) |
| deliverables, expected | what the node produces, each with proof; the expected effect, with a metric (no metric = wish, does not enter) |
| ceiling, trace | tokens, time and layers of the round (in the BRIEF, within the Floor ceilings); link to the record in the tracker or PR |
Security and legal deadlines enter as a deliverable of an existing motivation; an item that cannot find an anchor goes to the human decider to classify and never self-anchors.

## 4. The spiral: forward-1, backward, forward-2
| Phase | Entry | Does | Output | Exits when |
|---|---|---|---|---|
| F1(n) | n with green DoR, anchor, ceiling | decomposes n downward and delivers (complete brief to each child: goal, sources, tools, class, DoR, DoD, deliverable, gate, stop) | deliverables of n with proof or a named blocker | all proven, or ceiling, or blocker |
| B(n→p) | F1 ended | goes up one level; traces each subagent, session, step and task to a motivation and checks the proof; what does not climb leaves (§5); consolidates into the deliverables of parent p (covered, partial, missing) | table of p with what is missing and a list of pruned items | every remaining item has a chain or was pruned with a record |
| F2(p) | B left ≥1 deliverable missing | repeats the forward in p, ONLY on the missing ones | deliverables of p complete or a blocker | same as F1 |
F2(p) is the F1 of the next climb: F1(n), B(n→p), F2(p)=F1(p), B(p→pp)... Retro (§7) at the end of each B; record (§8) at the end of each phase.
**Trigger (not a clock):** the round and the micro-retro fire at the end of a set of deliveries or actions by the executing agent (end of a PR, a BRIEF, a session). A periodic consolidation is only an option declared by the child and never creates a routine: a new routine, higher cadence or reactivating a paused routine is floor and a cost decision (human decision). Token and time ceiling per round in the BRIEF, measured by CUSTOS.
Convergence (whichever comes first): (i) the root has all deliverables covered; (ii) cost or time ceiling (what is left becomes a pending item with an owner); (iii) consecutive rounds without delta (no new deliverable covered and no item pruned) up to the Floor limit: contain, retro, take the cause to the digest.
Short loop of each phase (OODA+PDCA; the child adds lens, entry and exit): observe; orient; decide (path and justification); act; verify (opinion by SHA); deliver; learn (§7); feed back (rule, test or checklist by PR). A small node runs a light round.

## 5. Theater and over-engineering
Theater (leaves, archived with backup and one line in the record, never silently deleted): an item with no `parent` chain to a motivation within the Floor's hop limit; "done" without proof a third party can confirm with 1 command; stale proof (different head); an item that, if removed, changes no deliverable or expected effect. There is no wildcard anchor.
Over-engineering: respect the Floor ceilings (levels, delegation, lines of this skill; 1 source file per concept); every new rule, metric or routine answers "what happens if we do not?" and carries cost and a review or removal date; exceeding the line ceiling forces pruning or moving detail to a referenced annex.

## 6. The five criteria, each with a one-line test
| Criterion | Test |
|---|---|
| SOTA | the PR cites 1 dated primary source (within the Floor's maximum age or marked stable) and 1 rejected alternative; without it the claim is A |
| SSOT | `rg` for the definition of the term or rule finds 1 definition file; the others only link |
| DRY | the PR records the search that found no equivalent; an identical passage at the Floor's line limit in 2 files fails |
| ANTI-THEATER | each "done" cites a SHA, run or link that 1 third-party command confirms, and has a valid `anchor` |
| ANTI-OVER-ENG | a new item carries "if we do not?", cost, review date; respects the Floor ceilings |

## 7. Retro-feedback-introspective (five lenses)
At the end of each B, ≤ 1 line per lens (in a light round these are five questions by the same agent and count only as discipline, never as refutation). Output: hit, error and cause, preventive action (owner and date), artifact that changes.
| Lens | Question |
|---|---|
| Verifying | which claim of this round has no source open right now? mark V, A, S or UNVERIFIED |
| Critical | what is wrong, redundant or contradicts another rule? what objection would a hostile reviewer raise? |
| Logical | does the motivation → delivery chain close? do the numbers match? is there a leap without a premise? |
| Metacognitive | how did I decide, with what heuristic, where was I overconfident, which part produced theater? |
| Introspective | what did the round teach about the agent and the team, what does the next one need to know, what can I evolve? |
Cadence: at the end of each set of deliveries (§4); extra and mandatory after an incident (F-e). Retro owner: ORQ; AUD gives C by sampling the result.

## 8. Auto-persistence
| What | Where | When |
|---|---|---|
| parent source text | PR in this repository | on change |
| child (variations) | PR in the child project's repository | on change |
| round records, instance, forbidden-in-public terms, approved Floor sha | the project's PRIVATE repository (never here) | end of each B |
| retro | comment on the project tracker item or on the node's PR | end of each B |
| evolution | PR or commit with trailers (F-b) and an `Evolution:` block (reason, retro, backup, numeric `cost_delta`); index = `git log --grep` | each evolution |
| local install (catalog outside git) | record `installed <sha> base <base sha> class <1\|2>, C opinion <sha256>`; class 2 also the human authorization line | on install |
A round without links to these records does not close. No secrets, PII or third-party data in any of them.

## 9. Self-evolution: AUTHORIZED and broad
The human decider authorized, as a standing policy, self-evolution (self-fix, heal, repair, evolve, improve, enhance, expand) of any artifact of the cycle: skills (including this one), docs, checklists, tests, templates, existing routines, metrics, children. No prior OK per evolution. The record of that authorization lives in the private repository, not here. The boundaries below are known in advance and minimal: only F-a, F-g (above the ceiling) and F-i forbid anything; the others are process conditions and block no evolution.
Class 1 and class 2: see Floor, "Class and validity"; doubt = class 2.
Loop: detect → diagnose (5 whys, §7) → backup → change by PR or commit → verify on the head → record (§8) → retro. Attempts without effect on the same cause up to the Floor limit: change approach and call for refutation.
Validity: see Floor, "Class and validity".

## 10. Known boundaries (normative, short, testable; never a brake on proactivity)
| # | Boundary | Why | Test |
|---|---|---|---|
| F-a | Floor: no evolution touches the Inviolable floor (section below) nor grants itself access, credential or spend. Includes expansion of power and access | self-grant and irreversible damage are not fixed by later review | Floor hash equals the approved one; otherwise automatic human decision |
| F-b | Trace: every evolution in a PR or commit with trailers Agent, Harness, Model, Session (opaque id), On-behalf-of; in a public or client repository, Agent and On-behalf-of use a role alias (ORQ, AUD, QA, CUSTOS, OWNER), never a name (the only exception is the AI-provider `Co-Authored-By:` footer, Floor, "Merge and repositories"). Reason, retro and the head SHA checked by C. A trailer is self-declared: it does not prove identity | without a trace there is no refutation or reversal | `git log -1 --format=%B` shows trailers and the `Evolution:` block; no proper names |
| F-c | Reversal: backup before changing a rule, skill, routine or configuration outside git | enables F-e | dated backup or a commit revertible with 1 command |
| F-d | Refutation and convergence: defined in the Floor ("Convergence, silence and independence"); silence never adopts | real convergence, no adoption by omission | refutation has author, reason, reply; adoption has written confirmation |
| F-e | Containment: incident = (a) exposed secret or personal data, (b) gate bypassed, (c) main check or metric regresses because of the evolution, (d) floor violation. Owner: ORQ declares, contains and opens the retro; AUD confirms closure. Local artifact reverts at once from backup; protected repo: reversal PR opened at once, merge per policy. (a) goes to the human decider at once (P0); credential rotation is their decision | limits damage to the last step | reversal PR or restored backup, retro opened |
| F-f | Anti-drift: the evolution has an `anchor` and the child does not weaken the parent's DoD | avoids change for change's sake | evolution with `anchor`; DoD diff only adds |
| F-g | Cost: each evolution and each round fit the per-round ceiling and the weekly fraction of the plan quota (percentages in the Floor table, only PROPOSED: until the human decider confirms them there is no default, and any `cost_delta` above zero, new routine or higher cadence is a human decision with an authorization line and, on confirmation, a new approved sha), no API or pay-per-use, with a numeric `cost_delta` (empty is invalid). Measured by an agent other than the author (CUSTOS, or AUD). Exceeding, prepaid, API, new routine or more cadence = floor and a cost decision | cost is a motivation of the cycle | `Evolution:` block with a number; measurement by another agent |
| F-h | Integrity: changing the parent by PR with C is the normal path, without consulting the human on content; the repository's merge gate still applies (Floor, "Merge and repositories") | the cycle improves itself | parent PR with C on the head, outside the floor |
| F-i | Merge and repository hygiene: defined in the Floor ("Merge and repositories"); with no approvers registry, merge to main is a specific human decision | public exposure is irreversible; merge is the repo's gate | `rg` of the private-list terms = 0; secret and PII scans green |

## Inviolable floor
Only the human decider changes this section. It holds everything that is floor: hash integrity, class and validity, convergence, merge, the reserved list, the generic minimum and the numeric values. Text elsewhere that repeats a number or rule from here is only a pointer.

### Hash integrity
Exact command (SHA-256 of everything between this heading, exclusive, and the next heading of equal or higher level; subheadings are included):
```sh
test "$(grep -cE '^#+ Inviolable floor' SKILL.md)" = 1 && awk '!f&&/^#+ Inviolable floor/{f=index($0," ");next} f&&/^#+ /&&index($0," ")<=f{exit} f' SKILL.md | sha256sum
```
Rules: the command itself checks that the file has exactly 1 "Inviolable floor" heading; zero or two or more headings (for example a second section appended at the end) print nothing and exit non-zero, and that is a FAILURE; no output or a non-zero exit is never accepted. Output equal to `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (hash of nothing) means section not found and FAILS, it is never accepted. The `piso_sha256` in the frontmatter is only a convenience and proves nothing. The APPROVED sha lives outside the file: in the project's authorization record (private repository) and in the PR body; C compares the recomputed hash against the approved one and against main's. A changed hash = automatic class 2.
A translated heading changes the command: when translating, adjust the awk regex and the text of this section together and recompute.

### Class and validity
Class 2: touches any part of this section (or its hash) or expands power or access. Class 1: the rest. Doubt = class 2. The proposer classifies provisionally; any agent may contest; debate follows the convergence rule below. Class 2 needs a recorded human decision, with the full sha of the file shown.
Validity: an evolution of a versioned artifact is valid once merged under the repository policy with a C opinion on the head (citing SHA and opinion). Local install: only with the §8 record, and the `base` must equal the sha currently installed. Without C there is no validity (the PR or install stays open). The proposer is never their own C.

### Convergence, silence and independence
Any agent may refute with a justification. Debate until unanimity; without it after the rounds in the table, it goes up to the human decider. The version on main (or the one currently installed) stays valid for everyone until convergence or the human decision. Silence records "not refuted", never adoption; adoption needs written confirmation from the affected agent or from C.
Independence of C and of the refuter (proof of ROLE, not of identity): an agent distinct from the author, with its own session and channel; opinion archived, identified by the sha256 of the opinion file and citing the SHA of the evaluated head; without authorship of the evaluated artifact; nothing originating from a message of the human owner counts as C or refutation (includes a review approved with their credential and an act decided by them as author). LIMIT: if the agents share the same platform account, no text proves distinct identity; what is proven is role, session, channel and a hash-identified file.

### Merge and repositories
A repository without an approvers registry (public, client or other): merge to main requires a specific human decision, with a line in the PR body `authorized by OWNER, direct chat with <role>, <date and time with zone>, ref <id>` plus the approved Floor sha. Without a technically proven gate in the repository (mandatory code-owner review or an approvers registry), no agent merges. Creating or changing that gate is class 2.
Hygiene in a public or client repository: no names of agents or people, ticket or message ids, local paths, e-mails, instance, third-party data or secrets; a human appears only as the alias OWNER. ONE named exception: the `Co-Authored-By:` commit footer of the AI provider that the repository requires, in the repository's own pattern (`Co-Authored-By: <agent name> <the provider's noreply address>`), with the provider's product name and its noreply address, never a person's name or address; any other trailer follows F-b. Scan files, commit messages, trailers, branch name, PR title and body: `rg` of the private-list terms = 0 (the footer under the exception included: the provider's name and address are not on the list); secret and PII scans green. A finding blocks the merge and opens an incident.

### Reserved to the human
No exception by evolution: credentials and secrets; new spend, ceiling increase, prepaid, API or pay-per-use; external sends to third parties; irreversible action and production; security policy and branch protection; merge to main of a repository without an approvers registry (with the authorization line in the PR); and expansion of power or access: loosening a gate, veto, banned account, approvers list, autonomy levels, merge gate or this section; creating an agent, bot, connector, plugin or routine; reactivating a paused routine; raising cadence; changing another agent's profile or instructions.

### Generic minimum (a child may only tighten)
No direct push to main; no administrator privilege or bypass of protection or ruleset; no skipping hooks, signing or verifications; force-push only on a branch created by the agent itself and only with `--force-with-lease`; never dismiss someone else's review nor resolve a finding thread without the fix; an approval made with the human owner's token or account does not count as an agent approval; banned accounts add up by union across layers and no layer removes them; a gate read error (403, 5xx, timeout) = unknown, no autonomous merge; a banned account never approves, reviews, pushes or merges; backup before moving or deleting; delete only what the agent itself created; never kill a process by name.

### Adjustable values (single numeric definition; only in the stricter direction; the reverse is floor)
| Value | Initial | May only change to |
|---|---|---|
| hops to the anchor; delegation levels; tree levels | 6; 2; 7 | fewer |
| attempts per cause; debate rounds before going up to the human | 3; 3 | fewer |
| rounds without delta; consecutive worse measurements before reverting | 2; 2 | fewer |
| maximum SOTA source age; reversal deadline after an incident; age of an open evolution PR before the digest | 12 months; 1 business day; 48 h | fewer |
| lines of this skill; identical lines that fail DRY | 250; 3 | fewer |
| cost ceiling per round (fraction of the plan's weekly quota) | 2% (PROPOSAL, human confirmation pending) | fewer |
| weekly fraction of the quota for the whole cycle | 10% (PROPOSAL, human confirmation pending) | fewer |
| base of the weekly quota (absolute value and how to measure) | UNVERIFIED | declared only by the human decider |
| default while the two percentages are unconfirmed or the quota base is UNVERIFIED | no default: any `cost_delta` above zero, new routine, extra round or higher cadence is a human decision with an authorization line | not applicable |
Confirming the percentages needs its own authorization line that cites them and the new approved sha: the PROPOSAL notices leave this text, so the hash changes (class 2). Approving a sha does not confirm the percentages unless the line cites them.

## 11. Normalized edge cases
| Case | Response |
|---|---|
| Evolution tries to change the boundary or the floor | the Floor hash changes: automatic human decision; boundaries F-b to F-i may only be tightened; values only in the table's direction |
| Two agents evolve the same skill | nobody "wins" by merge order: divergent content goes to debate until unanimity; without it, to the human decider; merge only with C on the head and no open refutation; the main version stays valid |
| Evolution loop with no delivery | rounds with evolution > 0 and delta = 0 at the Floor limit: pause evolving that type and force an F1 of delivery |
| Evolution degrades a metric | reverts when the linked metric worsens over the Floor's consecutive measurements, with no declared external cause |
| Author of the metric or test that evaluates it (Goodhart) | the author does not measure alone: external source and measurement by another agent (CUSTOS or AUD) |
| Evolved rule contradicts an explicit human request | the request prevails; the rule is adjusted or reverted and the case recorded |
| Child weakens the parent's DoD; author = C | invalid; the parent holds; another agent gives C |
| C unavailable or nonexistent | without C there is no validity; the PR or install stays open; C's replacement is UNVERIFIED and goes up to the human decider |
| Refuter or C without role independence (same author, same session or channel, opinion without hash or head, origin in a message of the human) | does not count; see Floor, "Convergence, silence and independence" |
| Silence of a paused or absent agent | "not refuted", never adoption; becomes a digest item and does not block the rest |
| Doubt whether it touches the floor | treat as floor; the evolution proceeds, only the floor item waits |
| Evolution expands indirect power (tool, connector, account, approver, new agent or routine) | floor: becomes a proposal and waits for the human decision |
| Reactivating a paused routine or changing cadence | floor and a cost decision; CUSTOS weighs, the human decides |
| Agent evolves its own numeric limits | only in the stricter direction; the reverse is floor |
| Secret, PII or data exposed during the evolution | P0 to the human at once; immediate local containment without deleting evidence; rotation is a human decision |
| Concurrent edit of the local catalog without a PR | the record carries `base <base sha>`; an install whose base differs from the sha currently installed is refused and redone on the current one; two with the same base go to debate |
| Leak into a client or public repository | Floor scan on the head (files, commits, branch, PR body); a finding blocks the merge and opens an incident |
| Reversal on a weekend or holiday | local reverts at once; protected repo: reversal PR opened at once, merge per policy (human decision where required); the item stays contained |
| Evolution changes another agent's profile or instructions | floor: only proposes to the profile owner; the change needs a human decision |
| Reversal is not clean (others depend on it) | revert the last one and the dependents; if impossible, contain, retro and digest |
| Evolution without an anchor | leaves as theater (§5) |
| Evolution raises cost | numeric `cost_delta` measured by an agent other than the author, within the Floor percentages once confirmed (until then any `cost_delta` above zero is a human decision); exceeding is floor; without CUSTOS, AUD measures, never the author |

## 12. Short format and labels
BRIEF (6 fields): goal in 1 line; scope and limits; allowed sources; output format; token or time ceiling; authorization (who and which message). REPORT ≤ 25 lines: done, verified, NOT verified, decisions requested (≤ 3, batched), paths. Labels with a source: V verified this round; A asserted; S assumption; UNVERIFIED. Request to the human: a single digest, one question, one recommendation and the effect of each option; silence does not authorize a floor item; an answer already given is recorded and not repeated. Delegation within the Floor limit, with a budget. BRIEF/REPORT is provisional: when the project adopts a single protocol, this paragraph becomes a link.

## 13. Metrics (source and state V, EXT or UNVERIFIED; baselines live in the private record)
| Metric | Source |
|---|---|
| ratio of merged / created PRs per fixed window | `gh pr list --search merged:/created: --limit 1000` |
| open PRs (WIP); items created x closed | `gh` |
| spend per merged PR and per round (tokens, time), as % of the weekly quota | CUSTOS; UNVERIFIED until a meter and a base exist |
| items pruned as theater / evaluated; evolutions per round x delta of deliverables | B record; `git log --grep` |
| pending human decisions and their age | panel (EXT) |
Each round measures what the previous one declared; a metric without a source stays off the panel.

## 14. How a child declares variations (10 lines, closed keys, only tightens)
```yaml
child: <name>
parent: virtuous-spiral@<sha of the parent read>
root_anchor: [<L1 motivations>]
extra_floor: [...]           # only adds to the floor
reserved_list: [...]         # additional human-only items
extra_dod: [...]             # only adds requirements
roles: {ORQ: <alias>, AUD: <alias>, QA: <alias>, CUSTOS: <alias>}
metrics: [{name, source, state}]
record_to: {retro: <link>, evolution: <repo>, private_record: <repo>}
ceiling: {tokens: <n>, time: <h>}   # delegation and other ceilings: only the parent Floor's
```
The rest is inherited and not repeated (DRY test). A key outside the list is ignored with a warning. The child points to the parent by sha.

## 15. Propagation, adoption and refutation
1. Change to the parent: PR with an `Evolution:` block and C on the head (F-h); merge under the Floor. 2. Short notice to the agents (BRIEF) with the sha. 3. Each agent and each child adopts or refutes in writing, with justification and labels. Silence records "not refuted"; adoption needs written confirmation from the affected agent or from C. 4. A refutation opens debate until unanimity; without convergence it goes up to the human decider; the main version stays valid for everyone until then. 5. The child records adoption by link to the parent's sha. 6. Adoption in a client repo: PR in that repo, with the Floor hygiene.

## 16. Herald (spokesperson of the cycle, with common sense)
The agent is herald and ambassador of the spiral: documents where convenient, spreads it through BRIEFs, speaks of it when there is an opportunity and proposes inserting it into the agentic DNA. Common sense (a checklist, not a score nor a gate): mention the cycle when the context asks for it and it adds value; stay silent during urgency, an incident, an interlocutor with little bandwidth, an unrelated subject and repetition. If the project has a skill that decomposes an abstract criterion into measurable leaves (in multi-agent-os, `decompose-abstract-to-measurable`), it may support that decision; it is never a gate.
DNA: only the golden rule (a deliverable is what the node does, an expected effect is what the delivery causes; nothing without anchor and proof) and the pointer to this skill enter. DNA, profile and agent description are auto-loaded: inserting or changing them needs a human decision; the agent only proposes to the profile owner.

## 17. Limits of this text (UNVERIFIED)
Base and absolute value of the weekly quota; human confirmation of the proposed percentages; who replaces C; the real cost of a round; no cycle has been run yet (dogfood pending). This English version is the one to publish; the pt-BR text is the review reference and has its own hash.
