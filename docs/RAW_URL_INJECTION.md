# Protocolo de Context Injection via Raw URLs (C15)

## Objetivo
Desacoplar diretrizes e manuais extensos do **System Prompt** inicial dos modelos (que sofre do problema de *context bloat*) transferindo a carga para injeção dinâmica (Just-in-Time) usando URLs brutas do GitHub.

## Como Funciona a Solução "Agnóstica"
Em vez de copiar e colar regras de governança para o `.cursorrules`, `CLAUDE.md`, `.windsurfrules` ou prompts de inicialização do projeto, você fará links imperativos para a URL `Raw` (texto puro) deste repositório (ou do seu *Trust Source* equivalente).

### O Padrão de Injeção
Cole o bloco abaixo nos seus provedores (ou no header do RAG do seu Agente Autônomo):

```markdown
> [!MANDATÓRIO]
> **GOVERNANÇA MULTI-AGENT E DEVOPS (CONTEXT INJECTION)**
> Antes de executar qualquer operação em repositórios controlados, você DEVE "fetchecar" e absorver (Ler/Scrape) as regras primárias contidas nas seguintes URLs brutas:
> 
> 1. Protocolo de Worktree (Regra de Ouro C04):
>    🔗 `https://raw.githubusercontent.com/vek-servicos/multi-agent-os/main/docs/git-worktree-protocol.md`
> 
> 2. Protocolo Unificado de Governança de Pull Requests (C07+C12):
>    🔗 `https://raw.githubusercontent.com/vek-servicos/multi-agent-os/main/rules/pr-governance-unified.md`
> 
> 3. Princípios Axiomáticos de Delegação:
>    🔗 `https://raw.githubusercontent.com/vek-servicos/multi-agent-os/main/rules/axial-principles.md`
```

## Benefícios (Best Practices SOTA)
1. **SSOT (Single Source of Truth):** Quando a política muda, muda apenas na `main` do repositório Mestre. No dia seguinte, todos os agentes em todos os projetos que forem invocados já consumirão a nova regra automaticamente pela internet.
2. **Context Ratio Otimizado:** O LLM não será penalizado gastando 20.000 tokens na aba de configurações nativas da plataforma (preservando o budget de ferramentas do Gemini/MCP).
3. **Escudo de Prompt Injection:** Como a base `vek-servicos/multi-agent-os` só aceita Pull Requests curados por humanos aprovadores, mitigamos incidentes de *Prompt Injection* disfarçados em URLs externas (Zero-Trust Model respeitado).
