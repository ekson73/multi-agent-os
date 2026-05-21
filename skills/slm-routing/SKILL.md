---
name: slm-routing
version: 1.0.0
description: >
  Declarative decision rubric for routing AI work between a small local
  language model (SLM) and a remote frontier LLM. Closes Gap G3 of the
  OS3PD manifesto v4.13.0 (Principle 5 — Minimize Campfire Impacts).
  This skill is **pure markdown** — no runtime code. It documents the
  task-triviality and token-budget thresholds at which the cheaper local
  model is the better tool, and the failure modes that mandate routing
  remotely. Sister of `response-compression/SKILL.md` along a different
  axis: that skill controls **what is said** (verbosity); this one
  controls **where it is sent** (compute target).
protocols:
  - OS3PD-P5
agnostic: [os, project]
---

# SLM Routing

Routing a task between a small local language model (SLM, typically 1B–8B parameters) and a remote frontier LLM (typically 70B+ or proprietary) is the **FinOps and Green-IT axis** of context optimization. It is complementary to verbosity compression, which is documented separately in `skills/response-compression/SKILL.md`.

## When to Use

- Before invoking any LLM for a discrete sub-task, ask: "is this task in the SLM-eligible band?" If yes, prefer the local model.
- When `token-budget-gate.sh` raises `RULE-009` (Token Bloat) on a sub-agent spawn, this skill provides the routing answer to the question "could a cheaper model have produced this output adequately?".
- When the operator explicitly asks for "cheap mode", "local model only", or "no remote calls".

## Decision Matrix

The matrix below maps an objective signal (task type + input/output token budget) to a routing recommendation. The bands are intentionally conservative — when in doubt, prefer remote.

| Task class | Input tokens | Output tokens | Route to | Rationale |
|---|---|---|---|---|
| Regex / glob construction | < 512 | < 256 | SLM | Pattern synthesis is well-represented in small-model training; the consequence of a mistake is a syntactic error caught immediately by the regex engine. |
| Single-file lint / format | < 2k | < 1k | SLM | Local style rules; the file fits in a small context window; failures are caught by the linter itself. |
| Deterministic refactor (rename, parameter extraction, type-annotation insertion) | < 4k | < 2k | SLM | The diff is mechanical; LSP tooling catches semantic errors. |
| Inline code comment for a small function | < 1k | < 256 | SLM | The comment is descriptive, not normative. |
| Commit-message draft for a < 500-line diff | < 2k | < 512 | SLM | Templates dominate the output distribution; humans review before push anyway. |
| Multi-file architectural change | any | any | remote | Cross-file reasoning saturates small models quickly; the blast radius justifies the cost. |
| Code review for security-relevant code | any | any | remote | False-negative on a security flaw is materially worse than the marginal LLM cost. |
| API design / contract authoring | any | any | remote | Long-horizon consequences; remote reasoning is worth its cost. |
| Bug investigation requiring stack traces + multiple files | any | any | remote | Joint reasoning across log + code is where frontier models still dominate. |
| Any task with input > 32k tokens | > 32k | any | remote | Most SLMs cap usable context around 32k–128k with quality degradation past 8k–16k. |
| Anything where the answer must be cited from an external source | any | any | remote | Tool-use + retrieval coordination is fragile on small models. |

## Real Local SLMs (verify availability before invoking)

The following models are referenced as **examples** of locally-runnable SLMs that are commonly available through standard inference servers (Ollama, llama.cpp, vLLM, Hugging Face Text Generation Inference). The set is non-exhaustive and the field moves quickly — always verify against the host's installed model catalog before routing.

| Model family | Typical sizes | Strengths | Authoritative source |
|---|---|---|---|
| **Phi (Microsoft)** | 3.8B (`phi-3-mini`, `phi-3.5-mini-instruct`) | General reasoning, coding | <https://huggingface.co/microsoft/Phi-3-mini-4k-instruct> |
| **Gemma (Google)** | 2B (`gemma-2-2b-it`), 9B | Multilingual; safety-tuned | <https://huggingface.co/google/gemma-2-2b-it> |
| **Qwen-Coder (Alibaba)** | 1.5B / 3B / 7B (`Qwen2.5-Coder-*-Instruct`) | Code synthesis; multi-language code understanding | <https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct> |
| **Llama 3.2 (Meta)** | 1B / 3B (`Llama-3.2-3B-Instruct`) | Conversation, instruction-following | <https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct> |
| **DeepSeek-Coder** | 1.3B / 6.7B (`deepseek-coder-6.7b-instruct`) | Code completion; lower-resource workstations | <https://huggingface.co/deepseek-ai/deepseek-coder-6.7b-instruct> |
| **StarCoder2** | 3B / 7B / 15B | Code synthesis across 600+ languages | <https://huggingface.co/bigcode/starcoder2-7b> |

For empirical benchmarks against frontier models, consult the **HumanEval**, **MMLU**, and **MT-Bench** leaderboards published by the respective model authors and by independent evaluation suites such as `lmsys/chatbot-arena` and `eqbench`.

## Failure Modes That Force Remote Routing

Once any of the following is true, route remotely regardless of token budget:

- **Cross-file reasoning required.** The model must reconcile constraints across 3+ files.
- **Adversarial input handling.** Security-sensitive parsing or auth boundary work.
- **Multilingual + reasoning interaction.** SLMs degrade more steeply on multilingual reasoning than on either dimension alone.
- **Tool use orchestration.** Multi-step tool-use chains (search → read → edit → verify) are still unreliable on most SLMs.
- **Hard correctness budget.** When the cost of a single wrong answer exceeds the budget saved by routing locally — e.g., production code review.

## Anti-Patterns

- **Routing by model name vibe.** Don't pick a model because it has "coder" in its name — pick based on task class, input size, and required correctness.
- **Always-remote.** Defeats the purpose. If the SLM-eligible band fits the task, use it.
- **Always-local on a small workstation.** A 1B model on a laptop with 8 GB RAM will swap and the wall-clock cost dwarfs the per-token savings.
- **Routing by token count alone.** A 200-token security analysis is not SLM-eligible; a 6k-token regex test corpus is.
- **Silent fallback chains.** If an SLM returns a low-confidence answer, escalate explicitly — do not let the agent silently retry remotely with no audit trail.

## Sister Skills and Cross-References

| Concern | Where to look |
|---|---|
| Why this skill exists | `protocols/os3pd-manifesto.md` §P5 (Gap G3) |
| Verbosity axis (complementary) | `skills/response-compression/SKILL.md` |
| Token-bloat detection (deterministic side) | `plugin-scripts/governance/token-budget-gate.sh` (`RULE-009`) |
| Co-validation with PII scanning | `skills/pii-masking/SKILL.md` (P6, Gap G1; routing must NOT bypass the PII firewall) |
| FAIR / explainability axis | `skills/ttl-policy/SKILL.md` + `protocols/hierarchical-merge-protocol.md` |

## What this Skill is NOT

- ❌ A model registry. It does not list every SLM; the field changes monthly.
- ❌ A runtime router. The decision is made by the operator or the agent at invocation time — no hook intercepts and re-routes silently.
- ❌ A cost calculator. The matrix is qualitative; integrate with the host's FinOps tooling for hard numbers.
- ❌ A replacement for human judgement. The matrix is a starting point; promote tasks to remote whenever the cost of being wrong dominates the cost of remote tokens.
