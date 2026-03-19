# Forge Agent Design — RBAD Organization Overlay [C14.1]

<!-- Auto-loaded rule | Version: 2.0.0 | 2026-03-13 -->
<!-- Community protocol: multi-agent-os/protocols/rbad.md (MAOS plugin) -->
<!-- This file contains ONLY Org-specific extensions to the community RBAD protocol -->

> **Community Protocol**: For the full RBAD protocol (Goldilocks Principle, Atomicity,
> 6-Category Taxonomy, Decision Framework, anti-patterns), see MAOS `protocols/rbad.md`.
> This overlay adds Org-specific harmonization and persistence paths only.

## Organization Persistence Paths

```
ONDE SALVAR (Org):
  Global (todos os projetos): ~/.claude/rules/agent-{SIGLA}.md
  Projeto-especifico:         .claude/rules/agent-{SIGLA}.md
  MAOS plugin (community):    multi-agent-os/agents/{name}.md

NAMING:
  agent-pm.md, agent-dba.md, agent-qa.md, agent-sec.md
  agent-dev-be.md, agent-dev-angular.md, agent-dev-java.md
```

## Harmonizacao com AGENTS.md (Organization Projects)

Organization projects (ex: `my-example-api`) possuem AGENTS.md com regras locais
(Org Pantheon, protocolos de validacao). Hierarquia:

```
multi-agent-os/protocols/rbad.md (MAOS — community source of truth)
  ↓
~/.claude/rules/forge-agent-design.md (este — org overlay)
  ↓
{projeto}/AGENTS.md (projeto-local — pode estender com roles especificos)
  ↓
~/.claude/rules/agent-{sigla}.md (agentes criados — persistencia global)
```

### Organization Rules

- Projeto-local AGENTS.md pode definir roles adicionais do dominio
- Nomes mitologicos (Themis, Eunomia, Aletheia, Astraea) sao validos como Cat.6
  — funcao metaforica documentada e reconhecivel pela org team
- Nomes agora mapeados para MAOS community: Themis→governance-auditor,
  Eunomia→naming-organizer, Aletheia→data-validator, Astraea→validation-auditor
- NUNCA `.claude/agents/` (namespace nao padronizado for org)

## Org-Specific Roles (Extensoes Cat.3)

| Role | Escopo Atomico |
|------|----------------|
| Analista Fiscal | NF-e, SPED, ICMS, ISS, SUFRAMA, compliance fiscal |
| Analista Financeiro | Contas a pagar/receber, conciliacao, fluxo de caixa |
| Especialista LGPD | Privacidade, consentimento, DPA, DPIA |

---

*v2.0.0 | 2026-03-13 | Slimmed to Org-only overlay; RBAD protocol migrated to MAOS protocols/rbad.md*
*v1.1.0 | 2026-03-11 | Last full version before MAOS migration*
