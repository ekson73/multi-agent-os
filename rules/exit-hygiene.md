# Exit Hygiene — Vek Overlay [C13]

<!-- Auto-loaded rule | Version: 2.0.0 | 2026-03-13 -->
<!-- Community protocol: multi-agent-os/protocols/exit-hygiene.md (MAOS plugin) -->
<!-- This file contains ONLY Vek-specific extensions to the community protocol -->

> **Community Protocol**: For the full Exit Hygiene protocol (axioms, checklist,
> anti-patterns, priority hierarchy), see MAOS `protocols/exit-hygiene.md`.
> This overlay adds Vek-specific items only.

## Vek-Specific Exit Gate Items

### Metricas e Contadores (Vek)
- [ ] `prs_merged` em PROMPT bate com o real: `gh pr list --repo {owner}/{repo} --state merged | wc -l`
- [ ] Cross-references consistentes entre PROMPT_REENGENHARIA e PLANO_REENGENHARIA_MASTER

### MEMORY.md (Vek Paths)
- [ ] `~/.claude/projects/*/memory/MEMORY.md` atualizado com estado VERDADEIRO
- [ ] Sem notas de deferral: `grep -i "next session\|fix later\|TODO" ~/.claude/projects/*/memory/MEMORY.md`

### Emails / Notificacoes (Vek Accounts)

| Account | gog Profile | Content |
|---------|-------------|---------|
| `emilson.moraes@gmail.com` | default | GitHub notifications |
| `user@acme-corp.example.com` | vek | Jira, Confluence, Bitbucket |

- [ ] Emails de PR arquivados em AMBAS as contas (gog CLI)
- [ ] Gmail MCP: apenas @gmail.com (OAuth). NAO usar para @acme-corp.example.com

### Verificacao Pre-Saida (Vek Scripts)

```bash
# Contadores Vek
REAL=$(gh pr list --repo {owner}/{repo} --state merged | wc -l | tr -d ' ')
YAML=$(grep "prs_merged:" docs/00_index/PROMPT_REENGENHARIA.md | grep -oE '[0-9]+')
echo "Real: $REAL | YAML: $YAML | Match: $([ $REAL -eq $YAML ] && echo YES || echo NO)"

# MEMORY.md sem deferrals
grep -i "next session\|fix later\|TODO\|arrumar depois" \
  ~/.claude/projects/*/memory/MEMORY.md
```

## Origem e Motivacao (Vek Incident)

**Sessao 2026-03-07**: `prs_merged` ficou off-by-1 apos PR #57. Anotado como
"fix next session" — casca de banana classica. Custo de corrigir agora < custo
de contexto zero na proxima sessao.

---

*v2.0.0 | 2026-03-13 | Slimmed to Vek-only overlay; community protocol migrated to MAOS protocols/exit-hygiene.md*
*v1.3.0 | 2026-03-11 | Last full version before MAOS migration*
