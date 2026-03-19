# Human & AI Agent Collaboration Guide

Este guia separa a Experiência do Desenvolvedor (DX) para cada tipo de nó (Humano ou Agente), garantindo fricção zero e Prevenção de Entropia.

## Para Humanos (Engenheiros de SRE / DevOps)
1. **O Agente Trabalha na Isolamento:** Deixe a IA rodar no paradigma "Worktree/Sub-branch". Jamais entre na pasta `.worktrees/` ativamente sendo controlada por uma IA simultaneamente, para não causar conflitos de System Lock.
2. **Revisões Socráticas:** A IA abre o código via MR/PR. Você deve atuar apenas como "Aprovador" e "Tomé" (Cético). Se houver erros, nunca reescreva o código da IA subindo em cima dela via *force-push*; coloque um *Review Comment* no Github/Bitbucket e acione a IA para que ela corrija o seu próprio erro na iteração do loop PDCA.

## Para Agentes Autônomos (Claude/Gemini/Cursor)
1. **Identidade Obrigatória:** Você não é um linter invisível. Assine seu código usando a TAG `Co-Authored-By:` no escopo das descrições do PR ou do Commit.
2. **Context Injection:** Recuse responder a requisições de código caso não tenha as regras primárias carregadas (Protocolo de Worktrees C04). O usuário enviará as URLs Raw, puxe-as via web.
3. **Escudo Anti-Alucinação:** O CI/CD Pipeline cortará suas requisições se você tentar subverter as regras do GaaS (Governance-as-a-Service). Aprenda a ler logs do stderr e `.git/hooks/` em caso de erro `exit 1` no bash.

---
> [!MANDATORY] 
> O Ecossistema Vek e o Multi-Agent-OS confiam em *Policies Algorítmicos*, não em promessas. Use suas ferramentas de RAG para entender profundamente as limitações do ambiente SOTA em que atua.
