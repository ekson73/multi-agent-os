# Agent Delegation — Organization Overlay [C14]

<!-- Auto-loaded rule | Version: 2.0.0 | 2026-03-13 -->
<!-- Community protocol: multi-agent-os/protocols/agent-delegation.md (MAOS plugin) -->
<!-- This file contains ONLY Org-specific extensions to the community protocol -->

> **Community Protocol**: For the full Agent Delegation protocol (delegation chain,
> context format, Forge definition, bootstrap, anti-patterns), see MAOS
> `protocols/agent-delegation.md`. This overlay adds Org-specific registry only.

## Org Agent Registry (Ecossistema Atual)

| Dominio | Agente | Ativacao |
|---------|--------|----------|
| Git, codigo, docs, automacao | Claude Code | Sempre ativo |
| **Git, PRs, review, merge, cleanup** | **SCM** (Forge-created) | `SCM: {operacao}` |
| Arquitetura, ADRs, design | @architect (BMAD) | `*agent architect` |
| Produto, PRDs, roadmap | @pm / @po (BMAD) | `*agent pm` |
| Qualidade, testes, validacao | @qa (BMAD) | `*agent qa` |
| UX, experiencia do usuario | @ux-expert (BMAD) | `*agent ux-expert` |
| Code review (local) | CodeRabbit CLI | `cr review --plain --base main` |
| Code review (fallback) | Qodo CLI | `qodo --ci -y "prompt"` |
| Criacao de agentes | **Forge** (MAOS) | `Task(subagent_type="forge")` |
| Governanca, padroes | **Themis** → governance-auditor (MAOS) | `Task(subagent_type="governance-auditor")` |
| Organizacao, naming | **Eunomia** → naming-organizer (MAOS) | `Task(subagent_type="naming-organizer")` |
| Validacao de dados | **Aletheia** → data-validator (MAOS) | `Task(subagent_type="data-validator")` |
| Auditoria de validacoes | **Astraea** → validation-auditor (MAOS) | `Task(subagent_type="validation-auditor")` |

## Org-Specific Persistence Paths

```
Agentes globais:     ~/.claude/rules/agent-{SIGLA}.md
Agentes de projeto:  .claude/rules/agent-{SIGLA}.md
Forge (MAOS):        multi-agent-os/agents/forge.md (plugin auto-discovered)
```

## Integracao com C13 (Exit Hygiene — Org)

Ao fechar uma sessao, verificar:
- [ ] Delegacoes ativas tem rastreabilidade (Jira, MEMORY.md, PR comment)?
- [ ] Registrar pendentes: `MEMORY.md → "Delegado para [agente] via C14 — pendente"`

---

*v2.0.0 | 2026-03-13 | Slimmed to Org-only overlay; community protocol migrated to MAOS protocols/agent-delegation.md*
*v1.2.0 | 2026-03-11 | Last full version before MAOS migration*
