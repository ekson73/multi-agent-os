# Visão — MAOS como a plataforma curadora-integradora do commons agentic

> **Status:** North Star proposto (ratificação via `docs/adrs/ADR-007-curated-community-integration-platform.md`).
> **Uma frase:** MAOS é o **front-door confiável** para o *melhor vetado* do ecossistema agentic —
> índice + gate + adapter + guia — construído **por agentes**, ratificado **por humanos**.
> Prosa pt-BR · identificadores en-US.

## O problema (que nós vivemos)

Há uma infinidade de humanos e agentes criando soluções — muitas boas, muitas úteis. Continuar
criando as nossas **não está errado**; devemos. Mas falta uma peça: **um integrador das melhores
soluções que a comunidade cria.** O operador fica perdido — não sabe o que é bom, *bom pra quê*,
*o que usar*, *quando usar*; muitas vezes **nem sabe que determinada solução existe**.

A prova é a nossa própria pesquisa `agentic-moe-2026`: foi preciso um deep-research inteiro, com
gate de supply-chain, só pra mapear o que presta. Se **nós** precisamos disso, o operador comum está
à deriva. Ninguém ocupou esse lugar: marketplaces **listam**, awesome-lists **apodrecem** — nenhum é
ao mesmo tempo **curado · security-gated · mapeado-por-caso-de-uso · fresco · harmônico**.

## A virada de identidade

MAOS deixa de ser "um framework com tools próprias" e passa a ser, **também**, a **meta-solução**:
o **all-in-one confiável** pra acessar tudo mais que é bom e utilizável. Não é "integrar tudo que
bomba" (isso é firehose, vira ruído que apodrece) — é **integrar os poucos que ganham a passagem**
por uma barra alta, e entregá-los **com o conhecimento de o-quê/quando/por-quê**.

A cunha mais afiada — e a que ninguém faz — é a **educação/descoberta**: *"você nem sabia que isto
existe · é bom pra X · use no passo Y"*. Isso é guiar, não listar.

## As três faces de uma coisa só (a MAOS Hub)

```
                 ┌──────────────────────────────────────────────┐
   commons  ──▶  │  INTEGRADOR (inbound)                        │  descobre → veta → adapta → registra
   (GitHub,      │     ↳ gatekeeper agent + piso determinístico │
   marketplaces) │  REGISTRY (SSOT)                             │  o conhecimento vetado por tool
                 │     ↳ what·good-for·when·conflicts·activation │  (license·provenance·ttl·rollback)
   operador ◀──  │  CONSOLE (operator-facing)                  │  projeta: preset·categoria·caso-de-uso·
                 │     ↳ profile = INPUT do gating (com dente)  │  context-aware·prose-intent·safe-mode
                 └──────────────────────────────────────────────┘
        O integrador ALIMENTA o registry · o console PROJETA · o hub ENFORÇA.
```

## Como dois (eu e você) curam um ecossistema explodindo: curadoria agêntica

Dois humanos não curam o firehose à mão. A solução é **elegante e recursiva**: os agentes fazem o
legwork, o humano ratifica.

`intake/pipeline` (descobre + decide) → **piso determinístico de segurança** (`supply-chain-sentinel`
+ `ai-governance-linter` + gitleaks + sandbox) → **contribution-gatekeeper** (triagem, nunca decisão
sozinha) → `evaluator` → `dogfood-ledger` (gate de promoção) → `ttl-policy` (frescor / auto-deprecate).

**O integrador é construído pelos próprios agentes que ele integra.** O humano é o **ratificador
HITL**, não o curador braçal.

## O que NÃO é (as linhas que seguramos)

- **Não é "everything".** É o *melhor vetado e contextualizado*. O bias do gate é **rejeitar por
  default**; integrar é a exceção que se prova.
- **Não é re-host.** É **access**: roteia/adapta os melhores **onde eles vivem** (slot-adapter com
  provenance), não reimplanta tudo num monólito.
- **Não é agente decidindo segurança sozinho.** O reviewer-agent é alvo de injeção; ele triage, o
  **piso determinístico + HITL** decidem.
- **Não assume MIT.** Classifica SPDX de verdade (a pesquisa achou NOASSERTION / AGPL / NONE entre os
  tops) e grava em `THIRD_PARTY_NOTICES`/SBOM.

## O ethos (a alma)

Honrar quem cria: crédito no commit (`co-author-standard`), atribuição no registry, afirmação de
licença, agradecimento. É o respeito do `os3pd` + o espírito AAIF — **e** é estratégico (goodwill →
contribuições). Todo item — inclusive os nossos — carrega seu **fallback/rollback** (reversibilidade
como DoD). E porque ser o hub confiável nos torna **alvo** (lição xz/SolarWinds), o próprio MAOS-como
-distribuidor se blinda (releases assinados, SBOM, provenance).

## A verdade dura (pra não virar theater)

Isto é um produto de **curadoria-confiança-frescor** — uma operação editorial + de segurança
**perpétua**, não um build. O moat é **julgamento + frescor + confiança**. **Uma integração ruim que
escapa o gate destrói a confiança que é o produto inteiro.** Os 7 guardrails do ADR-007 são o preço —
e a razão de existir.

## Encaixe (DRY) e roadmap

~80% disto já existe e é **reúso**: a família `agentic-tool-*` (intake/forge/evaluator/trainer/
pipeline/dogfood-ledger) + `os3pd-manifesto` + `co-author-standard` + `ttl-policy` + a CI de
supply-chain + a família `concierge`. O genuinamente novo: o **registry SSOT** (com `activation`), o
**console** (profile-como-input-do-gating), o **slot-adapter** de 1ª classe e o **contribution-
gatekeeper**. Dimensionado em waves no handoff do Claude Code, **depois** da fundação de segurança da
WAVE-0 (ADR-006).
