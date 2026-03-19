# GaaS (Governance-as-a-Service): Installation & Setup Guide

A Governança deste repositório Mestre não é passiva. Ela deve ser instalada e enforçada nativamente atravéz dos 3 motores de Compliance (Hooks Locais, CI/CD e Policy-as-Code). 

Se você for um Agente de IA ou um Humano clonando e adotando este ecossistema SOTA, execute os passos a seguir:

## Motor 1: Proteção Perimetral Local (Git Hooks)
Você impedirá operações catastróficas (como Pushes na master ou commitar na raiz ignorando Protocolo de Worktree) na origem.

**Como Integrar em qualquer repositório vizinho:**
Em repósitorios que desejam herdar nossas regras, altere a rota padrão de githooks para apontar aos nossos motores.
```bash
# Se baixar este repositório como Submodule:
git config core.hooksPath .docs-compartilhadas/multi-agent-os/.githooks

# Se já está dentro do próprio multi-agent-os:
git config core.hooksPath .githooks
```

## Motor 2: Proteção na Nuvem (CI/CD Pipeline)
Os Hooks locais podem ser "bypassados" por um comando `git commit --no-verify`. Por isso a nuvem obriga a re-checagem.

**Como Integrar:**
Copie o arquivo `.github/workflows/ai-governance-linter.yml` deste repositório para o repositório destino.
Ele bloqueará a união orgânica do Pull Request se:
1. Padrão de Nomes não for usado (`Conventional Commits`).
2. A IA omitir o Co-Authored-By da descrição do PR.

## Motor 3: Policy-as-Code e Context Injection (Raw URLs)
A forma mais escalável de forçar um LLM a aprender a regra local do projeto hospedeiro é incluir nos prompts o link `Raw` dos protocolos:
1. Veja detalhes em `docs/RAW_URL_INJECTION.md`.
2. Adicione os URLs no `.cursorrules` ou `CLAUDE.md`.
