# Gerenciamento de Repositórios ~/.claude/

> **Versao**: 2.1.0
> **Criado**: 2026-01-22
> **Atualizado**: 2026-01-22
> **Autor**: Claude-Code
> **Status**: Especificacao final aprovada
> **Changelog**:
> - v2.1.0 - Whitelist `sessions/` e `plans/`, ADR05 (session reports commitados)
> - v2.0.0 - .gitignore v3.0 WHITELIST, nomenclatura genérica (`work` vs `personal`), arquivo renomeado
> - v1.2.0 - .gitignore v2.0 (75 linhas, proteção secrets)
> - v1.1.0 - PERSONAL.md → CLAUDE.md, typos corrigidos

---

## Problema

O diretório `~/.claude/` contém configurações de três naturezas:

| Categoria | Conteúdo | Sensibilidade |
|-----------|----------|---------------|
| **Work (Corporativo)** | Stack, templates, protocolos, regras | Baixa (interno) |
| **Personal** | Email pessoal, DOB, preferências | Alta |
| **Universal** | Core directive, protocolos genéricos | Nenhuma |
| **Runtime** | Cache, plugins, debug | N/A (não versionar) |

### Requisitos

1. Separar conteúdo pessoal do corporativo
2. Permitir sync via git para ambos
3. Funcionar localmente em `~/.claude/`
4. Não conflitar entre si
5. Manter hierarquia de leitura do Claude Code

---

## Inventário Atual (2026-01-22)

### Por Tamanho

| Diretório | Tamanho | Versionável |
|-----------|---------|-------------|
| `projects/` | 631 MB | ❌ Runtime |
| `plugins/` | 131 MB | ❌ Runtime |
| `debug/` | 62 MB | ❌ Runtime |
| `docs/` | 80 KB | ✅ Config |
| `rules/` | 24 KB | ✅ Config |
| `templates/` | 12 KB | ✅ Config |
| `scripts/` | 8 KB | ✅ Config |
| `plans/` | 32 KB | ⚠️ Temporário |
| `todos/` | 4 KB | ⚠️ Temporário |

### Por Categoria

| Arquivo/Pasta | Personal | Work | Universal |
|---------------|----------|------|-----------|
| `CLAUDE.md` | ❌ | ✅ | ✅ |
| `rules/user-rules.md` | ✅ (email, DOB) | ✅ (stack) | ❌ |
| `rules/pr-review-protocol.md` | ❌ | ❌ | ✅ |
| `docs/git-worktree-protocol.md` | ❌ | ❌ | ✅ |
| `docs/insights/` | ❌ | ❌ | ✅ |
| `templates/worktree/` | ❌ | ✅ | ❌ |
| `scripts/init-worktree.sh` | ❌ | ✅ | ❌ |

---

## 14 Soluções Analisadas

### Sessão Anterior (S1-S7)

| # | Solução | Resumo | Viabilidade |
|---|---------|--------|-------------|
| S1 | Monorepo + .gitignore | Tudo em 1 repo, ignorar pessoal | ⚠️ Médio |
| S2 | Git Submodules | Personal como submodule do vek | ❌ Complexo |
| S3 | Git Subtree | Merge de repos com histórico | ❌ Complexo |
| S4 | Chezmoi | Templates com conditionals | ❌ Overhead |
| S5 | VCSH | Multi-repos mesmo diretório | ⚠️ Médio |
| S6 | Branches + Merge | Base + overlays por branch | ❌ Conflitos |
| S7 | Symlinks + 2 Repos | Simples, links externos | ⚠️ Médio |

### Novas Soluções (S8-S14)

#### S8: Bare Repo Overlay (Multigit)

**Conceito**: Dois bare repos compartilhando o mesmo `GIT_WORK_TREE=$HOME/.claude/`.

```bash
# Setup
git init --bare ~/.claude/.git-vek
git init --bare ~/.claude/.git-personal

# Aliases
alias claude-vek='git --git-dir=$HOME/.claude/.git-vek --work-tree=$HOME/.claude'
alias claude-personal='git --git-dir=$HOME/.claude/.git-personal --work-tree=$HOME/.claude'

# Cada repo rastreia apenas seus arquivos
claude-vek add CLAUDE.md docs/ rules/pr-review-protocol.md
claude-personal add rules/user-rules.md
```

**Prós**:
- Zero conflitos (cada repo rastreia arquivos diferentes)
- Histórico separado
- Sem symlinks

**Contras**:
- Requer aliases
- Fácil confundir qual repo usar
- `git status` complexo

**Viabilidade**: ⚠️ Médio

---

#### S9: Work Primary + Personal Subdirectory (Sua Proposta)

**Conceito**: `~/.claude/` = clone do work, `~/.claude/personal/` = clone do personal.

```bash
# Setup
cd ~ && rm -rf .claude
git clone git@github.com:{org}/dot-claude.git .claude
cd .claude
git clone git@github.com:{user}/dot-claude.git personal
echo "personal/" >> .gitignore
git commit -am "chore: ignore personal subdirectory"
```

**CLAUDE.md do Work** inclui:
```markdown
## Personal Context (Opcional)

Se existir `~/.claude/personal/CLAUDE.md`, incorporar:
- Preferências de idioma
- Dados de contato (se necessário)
- Regras pessoais adicionais
```

**Prós**:
- **Oficializa** a estrutura (work controla)
- Usuário tem flexibilidade (pode ou não ter personal)
- Setup simples
- .gitignore protege

**Contras**:
- Personal fica "escondido" em subdirectory
- Duas operações git (um em cada diretório)

**Viabilidade**: ✅ Alto

---

#### S10: Personal Primary + Work Subdirectory

**Conceito**: Inverso do S9 - `~/.claude/` = personal, `~/.claude/vek/` = corporativo.

```bash
# Setup
cd ~ && rm -rf .claude
git clone git@github.com:{user}/dot-claude.git .claude
cd .claude
git clone git@github.com:{org}/dot-claude.git work
echo "work/" >> .gitignore
```

**CLAUDE.md do Personal** inclui:
```markdown
## Work Context

> **OBRIGATÓRIO**: Incorporar `~/.claude/work/CLAUDE.md`
```

**Prós**:
- Usuário tem controle total
- Fácil personalização

**Contras**:
- **Depende do usuário** incluir work no CLAUDE.md
- Pode esquecer de configurar
- Menos "oficial"

**Viabilidade**: ⚠️ Médio (depende de disciplina do usuário)

---

#### S11: YADM com Alternates

**Conceito**: Usar yadm com arquivos alternativos por host/classe.

```bash
# Setup
yadm clone git@github.com:{org}/dot-claude.git

# Estrutura
~/.claude/
├── CLAUDE.md                    # Base (todos)
├── CLAUDE.md##class.personal    # Overlay pessoal
├── rules/
│   ├── user-rules.md            # Base
│   └── user-rules.md##class.personal  # Overlay

# Ativar classe
yadm config local.class personal
yadm alt
```

**Prós**:
- Um repo apenas
- Overlays por classe/host
- Ferramenta madura

**Contras**:
- Requer aprender yadm
- Arquivos duplicados com sufixos
- Não trivial para novos membros

**Viabilidade**: ⚠️ Médio

---

#### S12: Git Sparse-Checkout com Dois Remotes

**Conceito**: Um repo local com dois remotes, sparse-checkout seletivo.

```bash
# Setup
cd ~/.claude
git init
git remote add work git@github.com:{org}/dot-claude.git
git remote add personal git@github.com:{user}/dot-claude.git

# Fetch ambos
git fetch work && git fetch personal

# Checkout work na raiz
git checkout work/main -- .

# Checkout personal em subdirectory
git checkout personal/main -- personal/
```

**Prós**:
- Flexível
- Um diretório .git

**Contras**:
- Conflitos de merge
- Histórico confuso
- Não recomendado pelo git

**Viabilidade**: ❌ Baixo

---

#### S13: Symlink Reverso (Personal Fora)

**Conceito**: `~/.claude/` = vek completo, `~/.claude-personal/` = repo pessoal separado, symlinks de arquivos específicos.

```bash
# Setup
git clone git@github.com:{org}/dot-claude.git ~/.claude
git clone git@github.com:{user}/dot-claude.git ~/.claude-personal

# Symlinks
ln -sf ~/.claude-personal/user-rules.md ~/.claude/rules/user-rules.md
ln -sf ~/.claude-personal/CLAUDE.md ~/.claude/personal/CLAUDE.md
```

**Prós**:
- Repos completamente separados
- Work não precisa saber de personal

**Contras**:
- Symlinks podem quebrar
- Git do vek vê symlinks, não conteúdo
- Mais complexo que S9

**Viabilidade**: ⚠️ Médio

---

#### S14: Include Pattern no CLAUDE.md

**Conceito**: Work repo tem CLAUDE.md que faz `include` dinâmico do personal se existir.

```bash
# Setup (igual S9)
git clone git@github.com:{org}/dot-claude.git ~/.claude
mkdir -p ~/.claude/personal  # Não versionado
```

**CLAUDE.md do Work**:
```markdown
# CLAUDE.md — Work Corporate

## Core Rules
...

## Personal Override (Auto-include)

<!-- Claude Code auto-expands includes -->
> **Include**: `~/.claude/personal/CLAUDE.md` (se existir)

Se o arquivo acima existir, suas configurações sobrescrevem as corporativas.
```

**Sem repo personal**: Usuário cria manualmente `~/.claude/personal/CLAUDE.md`.
**Com repo personal**: Usuário clona dentro de `personal/`.

**Prós**:
- Extremamente simples
- Zero conflito git
- Funciona sem personal

**Contras**:
- Claude Code não suporta `include` nativamente (precisa documental convention)
- Personal não versionado por padrão

**Viabilidade**: ✅ Alto (com convenção)

---

## Comparação: work/personal vs personal/work

### Cenário A: Work Primary (`~/.claude/` = work)

```
~/.claude/                 ← git clone work
├── .git/                  ← Repo work
├── .gitignore             ← Inclui "personal/"
├── CLAUDE.md              ← Work + include personal
├── personal/              ← git clone personal (ignorado pelo work)
│   ├── .git/
│   └── CLAUDE.md
├── docs/
├── rules/
└── templates/
```

| Critério | Pontuação |
|----------|-----------|
| **Oficialidade** | ✅ Work define estrutura |
| **Controle** | ✅ Work controla CLAUDE.md principal |
| **Flexibilidade** | ✅ Usuário pode ter ou não personal |
| **Onboarding** | ✅ Novo membro clona work, funciona |
| **Manutenção** | ✅ Work atualiza, todos recebem |

**Score**: 5/5

### Cenário B: Personal Primary (`~/.claude/` = personal)

```
~/.claude/                 ← git clone personal
├── .git/                  ← Repo personal
├── .gitignore             ← Inclui "work/"
├── CLAUDE.md              ← Personal (deve incluir work)
├── work/                  ← git clone work (ignorado pelo personal)
│   ├── .git/
│   └── CLAUDE.md
├── docs/
└── rules/
```

| Critério | Pontuação |
|----------|-----------|
| **Oficialidade** | ❌ Depende de cada usuário |
| **Controle** | ❌ Cada usuário decide se inclui work |
| **Flexibilidade** | ✅ Total para o usuário |
| **Onboarding** | ❌ Novo membro precisa configurar manualmente |
| **Manutenção** | ❌ Atualizações work não propagam automaticamente |

**Score**: 2/5

### Conclusão da Comparação

**work/personal é superior** porque:

1. **Governança**: A organização controla as regras base
2. **Compliance**: Garante que todos seguem os protocolos corporativos
3. **Facilidade**: Novo colaborador clona work → funciona imediatamente
4. **Opcional**: Personal é um "addon", não requisito
5. **Citação do usuário**: "já oficializamos a obrigatoriedade de chamada ao personal no CLAUDE.md"

---

## Comparação: Localização do Personal

### Opção A: `~/.claude/personal/`

```
~/.claude/
├── personal/              ← Subdirectory dedicado
│   ├── .git/
│   ├── CLAUDE.md
│   └── user-overrides.md
```

| Critério | Score |
|----------|-------|
| Separação clara | ✅ 5/5 |
| Descoberta | ✅ 5/5 (óbvio) |
| Git isolation | ✅ 5/5 |
| Namespace conflict | ✅ 5/5 (zero) |

**Total**: 20/20

### Opção B: `~/.claude/docs/personal/`

```
~/.claude/
├── docs/
│   ├── git-worktree-protocol.md  ← Work
│   ├── personal/                  ← Misturado
│   │   └── notes.md
```

| Critério | Score |
|----------|-------|
| Separação clara | ❌ 2/5 (misturado) |
| Descoberta | ⚠️ 3/5 |
| Git isolation | ❌ 1/5 (precisa nested repo ou gitignore complexo) |
| Namespace conflict | ❌ 2/5 (pode conflitar) |

**Total**: 8/20

### Opção C: `~/.claude/rules/personal/`

```
~/.claude/
├── rules/
│   ├── pr-review-protocol.md     ← Work
│   ├── personal/                  ← Misturado
│   │   └── my-rules.md
```

| Critério | Score |
|----------|-------|
| Separação clara | ❌ 2/5 |
| Descoberta | ⚠️ 3/5 |
| Git isolation | ❌ 1/5 |
| Namespace conflict | ❌ 2/5 |

**Total**: 8/20

### Conclusão da Localização

**`~/.claude/personal/`** é a melhor opção porque:

1. **Raiz clara**: Fácil de encontrar e entender
2. **Git próprio**: Pode ter seu próprio `.git/` sem conflito
3. **Gitignore simples**: Apenas `personal/` no .gitignore do vek
4. **Escalável**: Pode ter subdiretórios (docs, rules, templates pessoais)

---

## Recomendação Final

### Solução Aprovada: S9+S14 Híbrido (Automatizado)

**Decisões**:

| Item | Valor |
|------|-------|
| **Nome repo work** | `{org}/dot-claude` (privado) |
| **Nome repo personal** | `{user}/dot-claude` (privado) |
| **Dir personal** | `~/.claude/personal/` |
| **Include** | OBRIGATÓRIO (não opcional) |
| **Bootstrap** | Automático pelo agente |

### Solução Recomendada: S9 (Work Primary + Personal Subdirectory)

```
~/.claude/                          ← git@github.com:{org}/dot-claude.git
├── .git/
├── .gitignore                      ← Contém: personal/, projects/, plugins/, debug/
├── CLAUDE.md                       ← Principal (inclui referência ao personal)
├── personal/                       ← git@github.com:{user}/dot-claude.git (opcional)
│   ├── .git/
│   ├── CLAUDE.md                   ← Mesmo formato de ~/.claude/CLAUDE.md
│   ├── rules/                      ← Regras pessoais (via @import)
│   └── docs/                       ← Docs pessoais
├── docs/
├── rules/
├── templates/
└── scripts/
```

### Setup Recomendado

```bash
#!/bin/bash
# ~/.claude/scripts/setup-claude-home.sh

# 1. Clone work config
cd ~
rm -rf .claude  # Backup first if needed
git clone git@github.com:{org}/dot-claude.git .claude

# 2. (Opcional) Clone personal config
cd ~/.claude
if [ -n "$CLAUDE_PERSONAL_REPO" ]; then
    git clone "$CLAUDE_PERSONAL_REPO" personal
    echo "Personal repo cloned to ~/.claude/personal/"
else
    mkdir -p personal
    echo "# CLAUDE.md - Your personal overrides" > personal/CLAUDE.md
    echo "Created empty personal directory"
fi

echo "Setup complete!"
```

### .gitignore do Work Repo (v3.0 - WHITELIST)

> **Estratégia**: Ignorar TUDO por padrão, adicionar exceções explícitas.
> **Vantagem**: Segurança máxima - novos arquivos são automaticamente ignorados.

```gitignore
# ═══════════════════════════════════════════════════════════════════
# .gitignore para ~/.claude/ (Work Repository)
# Versão: 3.0.0 | Estratégia: WHITELIST (ignore-all + exceptions)
# Atualizado: 2026-01-22
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────
# PASSO 1: Ignorar TUDO por padrão (segurança máxima)
# ─────────────────────────────────────────────────────────────────────
*

# ─────────────────────────────────────────────────────────────────────
# PASSO 2: Exceções - arquivos raiz que DEVEM ser versionados
# ─────────────────────────────────────────────────────────────────────
!.gitignore
!CLAUDE.md
!README.md

# ─────────────────────────────────────────────────────────────────────
# PASSO 3: Exceções - diretórios que DEVEM ser versionados
# (IMPORTANTE: negar diretório E conteúdo separadamente)
# ─────────────────────────────────────────────────────────────────────

# docs/
!docs/
!docs/**

# rules/
!rules/
!rules/**

# scripts/
!scripts/
!scripts/**

# templates/
!templates/
!templates/**

# commands/
!commands/
!commands/**

# hooks/
!hooks/
!hooks/**

# agents/ (se necessário)
!agents/
!agents/**

# skills/ (se necessário)
!skills/
!skills/**

# sessions/ (session reports - C05 standard)
!sessions/
!sessions/**

# plans/ (plan mode files)
!plans/
!plans/**

# ─────────────────────────────────────────────────────────────────────
# PASSO 4: Re-ignorar arquivos sensíveis dentro das exceções
# (Proteção extra - caso alguém coloque secret em docs/)
# ─────────────────────────────────────────────────────────────────────
*.env
.env*
*credentials*
*secret*
*.key
*.pem
*.p12
*.log
*.bak
*.backup
```

### Por que WHITELIST (v3.0) é superior a BLACKLIST (v2.0)?

| Critério | Blacklist (v2.0) | Whitelist (v3.0) |
|----------|------------------|------------------|
| **Novos arquivos** | ⚠️ Tracked por padrão | ✅ Ignorados por padrão |
| **Secrets acidentais** | ⚠️ Risco de exposição | ✅ Proteção automática |
| **Manutenção** | ❌ Cresce com estrutura | ✅ Estável |
| **Linhas** | 75 | 55 |

### Arquivos que SERÃO versionados (via exceções)

| Item | Tamanho | Descrição |
|------|---------|-----------|
| `.gitignore` | ~2KB | Este arquivo |
| `CLAUDE.md` | ~53KB | Configuração principal |
| `README.md` | ~1KB | Documentação raiz |
| `docs/**` | ~80KB | Documentação |
| `rules/**` | ~24KB | Regras auto-load |
| `scripts/**` | ~8KB | Scripts utilitários |
| `templates/**` | ~12KB | Templates |
| `commands/**` | ~5KB | Comandos customizados |
| `hooks/**` | ~10KB | Hooks de sessão |
| `sessions/**` | ~50KB | Session reports (C05) |
| `plans/**` | ~32KB | Plan mode files |

**Total versionável**: ~277KB (vs ~800MB total do diretório)

### CLAUDE.md do Work (Trecho)

```markdown
## Personal Context (Opcional)

> Se existir `~/.claude/personal/CLAUDE.md`, as configurações pessoais são incorporadas.
>
> O personal repo é opcional e controlado pelo usuário individual.
> Setup: `git clone <seu-repo-personal> ~/.claude/personal/`

### Hierarquia de Leitura

1. `~/.claude/CLAUDE.md` (este arquivo - corporativo)
2. `~/.claude/personal/CLAUDE.md` (pessoal - se existir)
3. `./CLAUDE.md` (projeto específico)
```

---

## Bootstrap Automático (C00)

O agente DEVE executar automaticamente no início de TODA sessão:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FLUXO DE BOOTSTRAP (executar automaticamente, sem perguntar)          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Verificar: [ -d ~/.claude/personal ] && [ -f CLAUDE.md ]           │
│                                                                         │
│  2. Se NÃO existe:                                                      │
│     a) Tentar: git clone {user}/dot-claude ~/.claude/personal                   │
│     b) Se falha: mkdir + git init + criar CLAUDE.md template           │
│     c) Informar sobre push (não bloquear)                               │
│                                                                         │
│  3. Include: LER ~/.claude/personal/CLAUDE.md (OBRIGATÓRIO)            │
│                                                                         │
│  4. Continuar com tarefa                                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Script de Bootstrap (Idempotente v1.1.0)

```bash
#!/bin/bash
# ~/.claude/scripts/bootstrap-personal.sh
# Versao: 1.1.0 - Idempotente e cross-platform (macOS/Linux/WSL)

set -euo pipefail

PERSONAL_DIR="$HOME/.claude/personal"
CLAUDE_MD="$PERSONAL_DIR/CLAUDE.md"
GITHUB_USER=$(git config --global user.email 2>/dev/null | cut -d'@' -f1 || echo "")
PERSONAL_REPO="git@github.com:${GITHUB_USER}/dot-claude.git"

# Funcao para verificar se CLAUDE.md e valido (nao vazio, tem conteudo minimo)
is_valid_claude_md() {
    local file="$1"
    [ -f "$file" ] || return 1
    # Verifica se tem pelo menos 50 bytes
    local size
    size=$(wc -c < "$file" | tr -d ' ')
    [ "$size" -ge 50 ] || return 1
    # Verifica se contem header esperado
    grep -q "^# CLAUDE.md" "$file" 2>/dev/null || return 1
    return 0
}

# Funcao para criar backup
backup_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup"
    echo "[Bootstrap] Backup criado: $backup"
}

# Funcao para criar CLAUDE.md template
create_claude_md_template() {
    local created_date
    created_date=$(date +%Y-%m-%d)
    cat > "$CLAUDE_MD" << EOF
# CLAUDE.md — Personal Context

> **Versao**: 1.0.0
> **Criado**: ${created_date}
> **Status**: Template inicial

## User Profile

| Campo | Valor |
|-------|-------|
| **Name** | [Seu nome] |
| **Email** | [seu@email.com] |
| **Role** | [Seu cargo] |
| **Lang** | pt-BR |

## Preferences

### Idioma e Tom
- Portugues BR como padrao
- Tom profissional, direto
- Evitar advérbios excessivos

### Formato de Saida
- Markdown para documentacao
- Tabelas para comparacoes
- Code blocks com syntax highlighting

## Personal Overrides

<!-- Adicione aqui suas regras pessoais que sobrescrevem as corporativas -->

## Notes

<!-- Anotacoes pessoais, lembretes, contexto adicional -->

---
*Template gerado automaticamente por bootstrap-personal.sh*
EOF
}

# ============================================================
# FLUXO PRINCIPAL (IDEMPOTENTE)
# ============================================================

echo "[Bootstrap] Verificando ~/.claude/personal..."

# CASO 1: Diretorio existe E CLAUDE.md e valido -> SKIP
if [ -d "$PERSONAL_DIR" ] && is_valid_claude_md "$CLAUDE_MD"; then
    echo "[Bootstrap] OK - Personal ja configurado e valido"
    exit 0
fi

# CASO 2: Diretorio existe MAS CLAUDE.md esta vazio/corrompido -> BACKUP + RECRIAR
if [ -d "$PERSONAL_DIR" ] && [ -f "$CLAUDE_MD" ] && ! is_valid_claude_md "$CLAUDE_MD"; then
    echo "[Bootstrap] CLAUDE.md existe mas esta invalido/corrompido"
    backup_file "$CLAUDE_MD"
    create_claude_md_template
    echo "[Bootstrap] CLAUDE.md recriado a partir do template"
    exit 0
fi

# CASO 3: Diretorio existe MAS sem CLAUDE.md -> CRIAR ARQUIVO
if [ -d "$PERSONAL_DIR" ] && [ ! -f "$CLAUDE_MD" ]; then
    echo "[Bootstrap] Diretorio existe mas sem CLAUDE.md"
    create_claude_md_template
    if [ -d "$PERSONAL_DIR/.git" ]; then
        cd "$PERSONAL_DIR"
        git add CLAUDE.md 2>/dev/null || true
        git commit -m "chore: add CLAUDE.md template" --quiet 2>/dev/null || true
    fi
    echo "[Bootstrap] CLAUDE.md criado"
    exit 0
fi

# CASO 4: Diretorio NAO existe -> TENTAR CLONE OU CRIAR LOCAL
if [ ! -d "$PERSONAL_DIR" ]; then
    echo "[Bootstrap] Diretorio nao existe, tentando configurar..."
    mkdir -p "$HOME/.claude"
    cd "$HOME/.claude"

    # Tentar clone do repo pessoal (silencioso se falhar)
    if [ -n "$GITHUB_USER" ] && git clone "$PERSONAL_REPO" personal 2>/dev/null; then
        echo "[Bootstrap] Repo pessoal clonado com sucesso"
        is_valid_claude_md "$CLAUDE_MD" || create_claude_md_template
        exit 0
    fi

    # Clone falhou -> criar local
    echo "[Bootstrap] Repo remoto nao encontrado, criando local..."
    mkdir -p "$PERSONAL_DIR" && cd "$PERSONAL_DIR"
    git init --quiet
    create_claude_md_template

    cat > .gitignore << 'GITIGNORE'
# ═══════════════════════════════════════════════════════════════
# .gitignore para ~/.claude/personal/ (Personal Repository)
# Versão: 3.0.0 | Estratégia: WHITELIST
# ═══════════════════════════════════════════════════════════════

# PASSO 1: Ignorar TUDO por padrão
*

# PASSO 2: Exceções - arquivos raiz
!.gitignore
!CLAUDE.md
!README.md

# PASSO 3: Exceções - diretórios
!docs/
!docs/**
!rules/
!rules/**

# PASSO 4: Re-ignorar sensíveis
*.env
.env*
*credentials*
*secret*
*.key
*.pem
*.log
*.bak
GITIGNORE

    git add -A
    git commit -m "chore: initial personal context" --quiet

    [ -n "$GITHUB_USER" ] && git remote add origin "$PERSONAL_REPO" 2>/dev/null || true

    echo ""
    echo "[Bootstrap] Personal criado em: $PERSONAL_DIR"
    echo "[Bootstrap] Para sincronizar:"
    echo "  1. Crie repo: https://github.com/new (dot-claude, privado)"
    echo "  2. Push: cd $PERSONAL_DIR && git push -u origin main"
    exit 0
fi

echo "[Bootstrap] Estado inesperado - verifique manualmente"
exit 1
```

### Comportamento do Agente

| Situação | Ação |
|----------|------|
| personal/ existe | Include direto |
| personal/ não existe + repo GitHub existe | Clone → include |
| personal/ não existe + repo não existe | Criar local → informar push → include |

**O agente NÃO deve**: perguntar, esperar, bloquear
**O agente DEVE**: executar, informar brevemente, continuar

---

## Justificativa da Recomendação

| Critério | S9 (Recomendado) | Alternativas |
|----------|------------------|--------------|
| **Simplicidade** | ✅ 2 clones, 1 gitignore | S5-S8: Ferramentas extras |
| **Governança** | ✅ Work controla base | S10: Depende do usuário |
| **Flexibilidade** | ✅ Personal opcional | S1-S4: Rígidos |
| **Isolamento** | ✅ Repos independentes | S12: Conflitos |
| **Onboarding** | ✅ Clone work → funciona | S10-S11: Config manual |
| **Manutenção** | ✅ Git pull em cada | S6: Merge manual |

### Por que não outras soluções?

| Solução | Motivo de Rejeição |
|---------|-------------------|
| S1 (Monorepo) | Mistura pessoal no repo corporativo |
| S2-S3 (Submodules/Subtree) | Complexidade desnecessária |
| S4 (Chezmoi) | Overhead de ferramenta |
| S5 (VCSH) | Curva de aprendizado |
| S6 (Branches) | Conflitos de merge |
| S7 (Symlinks externos) | Quebra em diferentes máquinas |
| S8 (Bare overlay) | Confuso para operação diária |
| S10 (Personal primary) | Perde governança corporativa |
| S11 (YADM) | Complexo demais |
| S12 (Sparse checkout) | Anti-pattern git |
| S13 (Symlinks reversos) | Fragilidade |
| S14 (Include pattern) | Não suportado nativamente |

---

## ADRs (Architectural Decision Records)

### ADR01: S9 Work Primary + Personal Subdirectory

**Decisão**: Usar `~/.claude/` como work repo e `~/.claude/personal/` como personal repo.

**Justificativa**: Melhor trade-off entre governança corporativa, flexibilidade pessoal e simplicidade de setup. Score 5/5 na comparação (linhas 339-346).

**Alternativas rejeitadas**: S1-S8, S10-S14 (ver tabela de rejeição acima).

---

### ADR02: WHITELIST .gitignore (v3.0)

**Decisão**: Usar estratégia WHITELIST (`*` + exceções) em vez de BLACKLIST.

**Justificativa**: Segurança máxima - novos arquivos são automaticamente ignorados, prevenindo exposição acidental de secrets.

**Trade-off**: Requer manutenção explícita de exceções para novos diretórios versionáveis.

---

### ADR03: Repos Independentes (Não Symlinks)

**Decisão**: Usar dois repos git independentes, não symlinks ou submodules.

**Justificativa**: Symlinks quebram em diferentes máquinas (S13), submodules adicionam complexidade desnecessária (S2-S3).

---

### ADR04: Personal como Subdirectory

**Decisão**: Personal repo fica em `~/.claude/personal/` (não em `~/.claude-personal/` ou outro local).

**Justificativa**: Score 20/20 na comparação de localização - separação clara, git isolation, zero namespace conflict.

---

### ADR05: Session Reports Commitados

**Decisão**: Diretório `sessions/` deve ser commitado (whitelist no .gitignore), não ignorado.

**Justificativa**:
1. **Continuidade**: Agentes futuros podem ler histórico de sessões anteriores
2. **Handoff**: Transferência de contexto entre agentes documentada
3. **Auditoria**: Rastreabilidade de decisões e progresso
4. **Anti-conflito**: SSID único por agente previne conflitos de merge

**Implementação**: Adicionar `!sessions/` e `!sessions/**` ao .gitignore WHITELIST.

**Referência**: C05 Session Report Standard em `~/.claude/CLAUDE.md`.

---

### ADR06: Hierarquia Sandwich Documentada

**Decisão**: Documentar explicitamente a hierarquia de leitura "sandwich":
1. Work BASE → 2. Personal → 3. Project → 4. Work ENFORCE

**Justificativa**: Clareza sobre precedência de configurações, evita confusão sobre o que pode ser sobrescrito.

---

### ADR07: Segregação Explícita Work/Personal

**Decisão**: Conteúdo pessoal (nome, email, preferências) apenas em Personal repo; protocolos corporativos [CXX] apenas em Work repo.

**Justificativa**: Permite que múltiplos usuários usem o mesmo Work repo sem conflitos de dados pessoais.

---

## Proximos Passos

1. **Criar** repo `{org}/dot-claude` no GitHub (privado)
2. **Migrar** conteudo atual de `~/.claude/` (exceto runtime)
3. **Configurar** .gitignore adequado
4. **Documentar** setup no README
5. **Testar** com segundo usuario Work
6. **(Opcional)** Criar repo `{user}/dot-claude` (privado)

---

## Artefatos Criados

| Artefato | Localizacao | Descricao |
|----------|-------------|-----------|
| **Spec Atualizada** | `~/.claude/docs/dot-claude-multi-repo-spec.md` | Este documento |
| **Template Work** | `~/.claude/templates/repo/CLAUDE.md.work.template` | Estrutura sanduiche |
| **Template Personal** | `~/.claude/templates/repo/CLAUDE.md.personal.template` | Contexto pessoal |
| **Bootstrap Script** | `~/.claude/scripts/bootstrap-personal.sh` | Setup idempotente |

---

## Fontes

- [Atlassian: Bare Git Repository for Dotfiles](https://www.atlassian.com/git/tutorials/dotfiles)
- [ArchWiki: Dotfiles Management](https://wiki.archlinux.org/title/Dotfiles)
- [Chezmoi: Why Use Chezmoi](https://www.chezmoi.io/why-use-chezmoi/)
- [YADM vs VCSH Comparison](https://github.com/yadm-dev/yadm/issues/11)
- [Multigit: Overlapped Git Repositories](https://github.com/capr/multigit)
- [Germano.dev: VCSH and MR](https://germano.dev/dotfiles/)
- [GBergatto: Tools for Managing Dotfiles](https://gbergatto.github.io/posts/tools-managing-dotfiles/)

---

*Assinatura: Claude-Code | 2026-01-22T22:30:00-03:00*
*v2.1.0 - Whitelist sessions/plans, 7 ADRs documentados, compliance 100%*
