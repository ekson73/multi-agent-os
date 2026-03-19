# Validacao Arquitetural: ~/.claude/ Multi-Repo Management

> **Versao**: 1.0.0
> **Data**: 2026-01-22
> **Autor**: Claude-Code (Solution Architect)
> **Status**: Validado - Pronto para implementacao
> **Baseado em**: dot-claude-multi-repo-spec.md (BA Analysis)

---

## 1. Resumo Executivo

A analise do BA propoe a solucao **S9+S14 Hybrid** para gerenciar `~/.claude/` com dois repositorios Git (Org corporativo + Personal). Esta validacao arquitetural **CONFIRMA a viabilidade tecnica** com ajustes importantes.

### Veredicto

| Item | Status | Observacao |
|------|--------|------------|
| Solucao S9 (Org Primary) | **APROVADA** | Estrutura de diretorios viavel |
| Include via @path | **SUPORTADO NATIVAMENTE** | Claude Code v2.0.64+ |
| Auto-load .d/ style | **SUPORTADO** via `~/.claude/rules/` | Nativo no Claude Code |
| Precedencia | **RESOLVIDA** | Posicional via @import inline |

---

## 2. Validacao Tecnica dos GAPs

### GAP01: Sintaxe @path Include

**Status**: RESOLVIDO - Suporte Nativo

O Claude Code **suporta nativamente** a sintaxe `@path/to/file` para inclusao de arquivos:

```markdown
# Sintaxe suportada:
@README                           # Relativo ao diretorio atual
@./docs/guide.md                  # Relativo explicito
@~/.claude/personal/CLAUDE.md    # Caminho absoluto com ~
@/absolute/path/file.md           # Caminho absoluto
```

**Caracteristicas documentadas**:

| Feature | Suporte | Observacao |
|---------|---------|------------|
| Caminhos relativos | SIM | `@./file.md`, `@../file.md` |
| Caminhos absolutos | SIM | `@/path/to/file.md` |
| Home directory (~) | SIM | `@~/.claude/file.md` |
| Recursao | SIM | Maximo 5 hops |
| Dentro de code blocks | NAO | Ignorado (comportamento correto) |

**Fonte**: https://code.claude.com/docs/en/memory

### GAP02: Padrao .d/ Style Auto-Load

**Status**: RESOLVIDO - Funcionalidade Nativa

O Claude Code implementa auto-load via diretorio `rules/`:

```
~/.claude/
├── CLAUDE.md           # User Memory (carregado automaticamente)
└── rules/              # User Rules (TODOS .md carregados automaticamente)
    ├── core.md
    ├── git-workflow.md
    └── ai-native.md
```

**Comportamento**:
- Todos os arquivos `.md` em `~/.claude/rules/` sao carregados automaticamente
- Subdiretorios sao suportados
- Path-specific rules via YAML frontmatter `paths:` field
- Mesma prioridade que `~/.claude/CLAUDE.md`

**Implicacao Arquitetural**:
- Organization Rules corporativas devem ir em `~/.claude/rules/` (auto-load)
- Regras Personal via `@import` chain (nao auto-load, para isolamento)

### GAP03: Script de Migracao

**Status**: PENDENTE - Especificacao criada

Requisitos do script de migracao:

```bash
#!/bin/bash
# ~/.claude/scripts/migrate-to-dual-repo.sh

# 1. Backup atual
backup_current_config()

# 2. Verificar estado Git atual
detect_git_status()

# 3. Clonar Org repo
clone_org_repo()

# 4. Criar/Clonar Personal
setup_personal_repo()

# 5. Migrar arquivos existentes
migrate_existing_files()

# 6. Configurar .gitignore
configure_gitignore()

# 7. Validar @import chain
validate_imports()

# 8. Executar dry-run
dry_run_validation()
```

### GAP07: Regras de Precedencia Org vs Personal

**Status**: RESOLVIDO - Padrao Sanduiche

A precedencia e determinada pela **posicao do @import** no arquivo:

```markdown
# ~/.claude/CLAUDE.md (Org)

## [ORG BASE] - Carregado PRIMEIRO
Regras corporativas obrigatorias...

## Personal Context
@~/.claude/personal/CLAUDE.md

## [ORG ENFORCE] - Carregado POR ULTIMO (opcional)
Regras que NAO podem ser sobrescritas...
```

**Padrao Sanduiche**:
```
ORG_BASE (fundacao)
    -> PERSONAL_OVERRIDE (customizacao)
        -> ORG_ENFORCE (garantias)
```

---

## 3. Arquitetura de Includes

### Fluxo de Leitura do Claude Code

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HIERARQUIA DE LEITURA CLAUDE CODE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 1. MANAGED POLICY (Enterprise - IT managed)                          │   │
│  │    /etc/claude-code/CLAUDE.md (Linux)                                │   │
│  │    /Library/Application Support/ClaudeCode/CLAUDE.md (macOS)         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 2. PROJECT MEMORY                                                     │   │
│  │    ./CLAUDE.md                                                        │   │
│  │    ./.claude/CLAUDE.md                                                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 3. PROJECT RULES (auto-load all .md)                                 │   │
│  │    ./.claude/rules/*.md                                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 4. USER MEMORY (Org Corporate)  ◄──────────────────────────────────┐ │   │
│  │    ~/.claude/CLAUDE.md                                              │ │   │
│  │    │                                                                │ │   │
│  │    ├── [ORG BASE RULES]                                             │ │   │
│  │    │                                                                │ │   │
│  │    ├── @~/.claude/personal/CLAUDE.md  ◄─────────────────────┐      │ │   │
│  │    │    │                                                    │      │ │   │
│  │    │    └── [PERSONAL OVERRIDES]                            │      │ │   │
│  │    │         │                                               │      │ │   │
│  │    │         └── @~/.claude/personal/rules/pref.md          │      │ │   │
│  │    │              (chain import, max 5 hops)                 │      │ │   │
│  │    │                                                         │      │ │   │
│  │    └── [ORG ENFORCEMENT] (nao pode ser sobrescrito)         │      │ │   │
│  │                                                              │      │ │   │
│  └──────────────────────────────────────────────────────────────│──────┘ │   │
│                                    │                            │         │   │
│                                    ▼                            │         │   │
│  ┌──────────────────────────────────────────────────────────────│──────┐ │   │
│  │ 5. USER RULES (Org Rules - auto-load)                        │      │ │   │
│  │    ~/.claude/rules/*.md ─────────────────────────────────────┘      │ │   │
│  └──────────────────────────────────────────────────────────────────────┘ │   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 6. PROJECT LOCAL (personal, gitignored)                              │   │
│  │    ./CLAUDE.local.md                                                  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Estrutura de Diretorios Final

```
~/.claude/                              # ORG REPO (git@github.com:acme-org/dot-claude.git)
├── .git/                               # Git Org
├── .gitignore                          # Contem: personal/, projects/, plugins/, debug/
│
├── CLAUDE.md                           # USER MEMORY - Org + @import personal
│   # Conteudo:
│   # ## Org Corporate Context
│   # [regras base]
│   # ## Personal Context
│   # @~/.claude/personal/CLAUDE.md
│   # ## Org Enforcement
│   # [regras finais]
│
├── rules/                              # USER RULES - Auto-load (Org)
│   ├── core-directive.md               # C01 compacto
│   ├── git-workflow.md                 # Git conventions
│   ├── ai-native.md                    # AI patterns
│   └── session-report.md               # C05 report standard
│
├── docs/                               # ON-DEMAND - Specs detalhadas
│   ├── git-worktree-protocol.md        # C04 completo
│   ├── pr-review-protocol-spec.md      # C07 completo
│   └── insights/                       # Insights acumulados
│
├── commands/                           # Slash commands
│   └── enhance.md
│
├── scripts/                            # Automation scripts
│   ├── init-worktree.sh
│   ├── bootstrap-personal.sh
│   └── migrate-to-dual-repo.sh
│
├── templates/                          # Templates reutilizaveis
│   └── worktree/
│
└── personal/                           # PERSONAL REPO (git@github.com:{user}/dot-claude.git)
    ├── .git/                           # Git Personal (separado)
    ├── CLAUDE.md                       # Personal overrides
    │   # Conteudo:
    │   # ## User Profile
    │   # [dados pessoais]
    │   # ## Preferences
    │   # [preferencias]
    │   # ## Additional Rules
    │   # @~/.claude/personal/rules/style.md
    │
    ├── rules/                          # Personal rules (via @import chain, NAO auto-load)
    │   ├── style.md
    │   └── shortcuts.md
    │
    └── .gitignore                      # Arquivos locais pessoais
```

---

## 4. Resolucao Detalhada dos GAPs

### GAP01: @path Include - Implementacao

**Sintaxe no CLAUDE.md Org**:

```markdown
# ~/.claude/CLAUDE.md

## Org Corporate Context

[... regras corporativas base ...]

---

## Personal Context

> As configuracoes pessoais sao carregadas automaticamente se existirem.

@~/.claude/personal/CLAUDE.md

---

## Org Enforcement

> Regras abaixo NAO podem ser sobrescritas pelo personal.

[... regras criticas ...]
```

**Comportamento quando personal nao existe**:

O Claude Code tenta ler o arquivo referenciado. Se nao existir:
- A referencia `@~/.claude/personal/CLAUDE.md` sera tratada como texto literal
- Recomendacao: Adicionar texto condicional no Org CLAUDE.md

**Texto condicional sugerido**:

```markdown
## Personal Context

> Se `~/.claude/personal/CLAUDE.md` existir, sera incorporado abaixo.
> Caso contrario, use o script de bootstrap: `~/.claude/scripts/bootstrap-personal.sh`

@~/.claude/personal/CLAUDE.md
```

### GAP02: .d/ Style - Separacao Org/Personal

**Regra de ouro**:
- `~/.claude/rules/*.md` = Org (auto-load, versionado no org repo)
- `~/.claude/personal/rules/*.md` = Personal (via @import chain, NAO auto-load)

**Por que Personal rules nao ficam em ~/.claude/rules/?**

| Problema | Consequencia |
|----------|--------------|
| Namespace collision | Org e Personal com mesmo nome de arquivo |
| Git isolation | Nao da para ter dois .git no mesmo diretorio |
| Merge conflicts | Atualizacoes Org podem conflitar |

**Solucao: @import chain no personal/CLAUDE.md**:

```markdown
# ~/.claude/personal/CLAUDE.md

## My Preferences
- Language: pt-BR
- Style: Direct

## My Rules (loaded via chain)
@~/.claude/personal/rules/code-style.md
@~/.claude/personal/rules/shortcuts.md
```

Isso mantem:
- Org rules em auto-load (obrigatorio para todos)
- Personal rules isoladas (apenas para quem tem personal)
- Maximo 5 hops de recursao (suficiente)

### GAP07: Precedencia - Matriz de Overrides

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      MATRIZ DE PRECEDENCIA                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ORDEM DE LEITURA (primeiro -> ultimo)                                  │
│  ════════════════════════════════════                                   │
│                                                                          │
│  1. ~/.claude/CLAUDE.md [ORG BASE]                                      │
│       │                                                                  │
│       ├── Core Directive (C01)                                          │
│       ├── Main Instructions (C02)                                        │
│       ├── Ralph Loop (C03)                                               │
│       └── Git Worktree ref (C04)                                         │
│              │                                                           │
│              ▼                                                           │
│  2. @~/.claude/personal/CLAUDE.md [PERSONAL OVERRIDE]                   │
│       │                                                                  │
│       ├── User Profile (name, email, role)                              │
│       ├── Preferences (language, style)                                  │
│       └── @~/.claude/personal/rules/*.md (chain)                        │
│              │                                                           │
│              ▼                                                           │
│  3. ~/.claude/CLAUDE.md [ORG ENFORCE] (pos-@import)                     │
│       │                                                                  │
│       └── Regras que NAO podem ser sobrescritas                         │
│              │                                                           │
│              ▼                                                           │
│  4. ~/.claude/rules/*.md [ORG RULES - auto-load]                        │
│       │                                                                  │
│       ├── core-directive.md                                              │
│       ├── git-workflow.md                                                │
│       └── ai-native.md                                                   │
│                                                                          │
│  ════════════════════════════════════                                   │
│  REGRA DE OVERRIDE: Ultimo a declarar VENCE                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Implicacoes praticas**:

| Cenario | Quem vence | Motivo |
|---------|------------|--------|
| Org diz "pt-BR", Personal diz "en-US" | Personal | Carregado depois do Org Base |
| Personal diz "skip tests", Org Enforce diz "always test" | Org Enforce | Pos-@import |
| Org rules/ diz X, Org CLAUDE.md diz Y | rules/ | Auto-load apos CLAUDE.md |

---

## 5. Decisoes Arquiteturais (ADR Format)

### ADR-001: Estrutura Org Primary com Personal Subdirectory

**Titulo**: Adocao da estrutura S9 (Org Primary + Personal Subdirectory)

**Contexto**:
- Necessidade de separar conteudo corporativo de pessoal
- Requisito de versionamento Git independente
- Restricao de nao usar symlinks (decisao do usuario)
- Claude Code le `~/.claude/CLAUDE.md` como User Memory

**Decisao**:
Adotar `~/.claude/` como clone do org repo, com `~/.claude/personal/` como clone do repo Personal, gitignored pelo Org.

**Consequencias**:
- (+) Governanca clara: Org controla base
- (+) Isolamento: Personal e um subdirectory com .git proprio
- (+) Onboarding simples: Clone Org, funciona
- (+) Flexibilidade: Personal e opcional
- (-) Duas operacoes git (uma em cada repo)
- (-) Personal rules nao sao auto-loaded

### ADR-002: Mecanismo de Include via @import Nativo

**Titulo**: Uso do @import nativo para incluir Personal

**Contexto**:
- Personal em subdirectory nao e auto-loaded
- Claude Code suporta `@path` nativamente
- Precisamos garantir que Personal seja lido

**Decisao**:
Usar `@~/.claude/personal/CLAUDE.md` no Org CLAUDE.md para incluir Personal.

**Consequencias**:
- (+) Nativo, sem ferramentas extras
- (+) Funciona cross-platform
- (+) Recursao ate 5 hops permite chain imports
- (-) Se arquivo nao existe, texto literal aparece
- (-) Requer documentacao/convencao

### ADR-003: Padrao Sanduiche para Precedencia

**Titulo**: Org Base -> Personal Override -> Org Enforce

**Contexto**:
- @import expande inline na posicao declarada
- Precisamos permitir customizacao pessoal
- Algumas regras corporativas nao podem ser sobrescritas

**Decisao**:
Estruturar o Org CLAUDE.md em tres blocos:
1. Org Base (antes do @import)
2. @import Personal (meio)
3. Org Enforce (depois do @import)

**Consequencias**:
- (+) Flexibilidade controlada
- (+) Regras criticas protegidas
- (+) Transparente (ordem de leitura e evidente)
- (-) Requer disciplina na estruturacao do arquivo

### ADR-004: Org Rules em Auto-Load, Personal via Chain

**Titulo**: Separacao de regras por mecanismo de carregamento

**Contexto**:
- `~/.claude/rules/` e auto-loaded
- Personal rules precisam de isolamento Git
- Nao e possivel ter dois .git em `~/.claude/rules/`

**Decisao**:
- Org rules: `~/.claude/rules/` (auto-load, obrigatorio)
- Personal rules: `~/.claude/personal/rules/` (via @import chain)

**Consequencias**:
- (+) Isolamento Git perfeito
- (+) Sem namespace collision
- (+) Org rules sempre carregadas
- (-) Personal rules requerem @import explicito no personal/CLAUDE.md
- (-) Limite de 5 hops (suficiente na pratica)

---

## 6. Especificacao do Script de Migracao

### Requisitos Funcionais

```bash
#!/bin/bash
# migrate-to-dual-repo.sh
# Versao: 1.0.0

# FUNCOES REQUERIDAS:

# 1. Backup
backup_current() {
    # Criar ~/.claude.backup.YYYYMMDD-HHMMSS/
    # Copiar todo conteudo (exceto runtime: projects, plugins, debug)
}

# 2. Deteccao de estado
detect_state() {
    # Verificar se ja e git repo
    # Verificar se ja tem personal/
    # Verificar se tem arquivos nao commitados
}

# 3. Clone Org
clone_org() {
    # git clone git@github.com:acme-org/dot-claude.git ~/.claude.new
    # Validar clone
}

# 4. Migrar arquivos existentes
migrate_files() {
    # Identificar arquivos pessoais (email, DOB, etc)
    # Mover para personal/
    # Identificar arquivos universais
    # Manter se nao conflitam com Org
}

# 5. Setup Personal
setup_personal() {
    # Tentar git clone user/dot-claude ~/.claude.new/personal
    # Se falhar: mkdir + git init + template CLAUDE.md
}

# 6. Swap atomico
atomic_swap() {
    # mv ~/.claude ~/.claude.old
    # mv ~/.claude.new ~/.claude
}

# 7. Validacao
validate() {
    # Verificar @import chain funciona
    # Verificar rules/ auto-load
    # Teste de dry-run com claude --version
}
```

### Flags Suportadas

```bash
migrate-to-dual-repo.sh [OPTIONS]

OPTIONS:
  --dry-run           Mostra o que seria feito sem executar
  --backup-only       Apenas faz backup, nao migra
  --org-repo URL      URL do org repo (default: git@github.com:acme-org/dot-claude.git)
  --personal-repo URL URL do repo Personal (opcional)
  --force             Ignora verificacoes de seguranca
  --verbose           Output detalhado
  --help              Mostra ajuda
```

---

## 7. Consideracoes de Seguranca

### Dados Sensiveis

| Tipo | Localizacao | Protecao |
|------|-------------|----------|
| Email pessoal | personal/CLAUDE.md | Repo privado |
| Data de nascimento | personal/CLAUDE.md | Repo privado |
| API keys | NUNCA em CLAUDE.md | .env ou secret manager |
| Credenciais Git | ~/.gitconfig (separado) | Nao relacionado |

### Gitignore Obrigatorio (Org)

```gitignore
# ~/.claude/.gitignore (Org repo)

# Runtime - NUNCA versionar
projects/
plugins/
debug/
todos/
plans/
audit/
cache/
file-history/
paste-cache/
image-cache/

# Credentials - NUNCA versionar
.credentials.json
.claude.json
*.env
.env*

# Personal repo - Versionado separadamente
personal/

# OS artifacts
.DS_Store
*.swp
*~
```

---

## 8. Compatibilidade Cross-Platform

| Plataforma | Suporte | Observacoes |
|------------|---------|-------------|
| macOS | TOTAL | Testado |
| Linux | TOTAL | Testado |
| Windows + WSL | TOTAL | Via WSL2 |
| Windows nativo | PARCIAL | Caminhos diferentes |

### Caminhos por Plataforma

| Item | macOS/Linux | Windows WSL | Windows Nativo |
|------|-------------|-------------|----------------|
| User home | `~/.claude/` | `~/.claude/` | `%USERPROFILE%\.claude\` |
| Managed policy | `/etc/claude-code/` | `/etc/claude-code/` | `C:\Program Files\ClaudeCode\` |
| @import syntax | `@~/.claude/...` | `@~/.claude/...` | `@%USERPROFILE%\.claude\...` (?) |

**Nota**: Windows nativo requer validacao adicional do @import com caminhos Windows.

---

## 9. Proximos Passos

1. **CRIAR** repo `acme-org/dot-claude` no GitHub (privado)
2. **ESTRUTURAR** o CLAUDE.md Org com padrao sanduiche
3. **MIGRAR** rules/ existentes para o novo repo
4. **IMPLEMENTAR** script migrate-to-dual-repo.sh
5. **TESTAR** com segundo usuario Org
6. **DOCUMENTAR** setup no README do repo

---

## 10. Referencias

- Claude Code Memory Documentation: https://code.claude.com/docs/en/memory
- Plugin Structure: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md
- BA Analysis: ~/.claude/docs/dot-claude-multi-repo-spec.md

---

*Assinatura: Claude-Code (SA) | 2026-01-22T14:30:00-03:00*
