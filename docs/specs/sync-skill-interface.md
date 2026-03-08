# Sync Skill Interface Specification

<!-- ═══════════════════════════════════════════════════════════════════════════
     SPEC: Interface Padrão para sync-to-* Skills

     Localização: ~/.claude/docs/specs/sync-skill-interface.md
     Escopo: Todos os skills sync-to-* (git, notebooklm, etc.)
     Versão: 1.0.0
     Criado: 2026-01-23
     Autor: Claude-Code

     PROPÓSITO: Definir interface padrão que todos os sync skills devem
     implementar para garantir consistência e interoperabilidade.
     ═══════════════════════════════════════════════════════════════════════════ -->

---

## Visão Geral

Esta especificação define a interface padrão que todos os skills `sync-to-*` devem implementar para garantir:

1. **Consistência**: Mesma experiência de uso entre skills
2. **Interoperabilidade**: Todos skills funcionam com sync-orchestrator
3. **Previsibilidade**: Comportamento esperado e error handling padronizado

---

## Taxonomia de Skills

```
sync-orchestrator (coordenador)
    ├── sync-to-git (GitHub, Bitbucket, GitLab)
    ├── sync-to-notebooklm (Google NotebookLM)
    ├── sync-to-confluence (Atlassian Confluence)
    ├── sync-to-notion (Notion)
    └── sync-to-* (futuros)
```

---

## Interface Obrigatória

### 1. Comando Principal

Todo sync skill DEVE responder ao comando:

```bash
/sync-to-{target} [OPTIONS] [FILES...]
```

### 2. Flags Obrigatórias

| Flag | Tipo | Descrição | Obrigatório |
|------|------|-----------|-------------|
| `--dry-run` | boolean | Preview sem executar | SIM |
| `--json` | boolean | Output JSON-RPC | SIM |
| `--verbose` | boolean | Output detalhado | SIM |
| `--force` | boolean | Bypass validações | SIM |
| `--config <file>` | string | Arquivo de configuração | SIM |
| `--help` | boolean | Mostrar ajuda | SIM |
| `--version` | boolean | Mostrar versão | SIM |

### 3. Exit Codes

| Code | Significado |
|------|-------------|
| `0` | Sucesso |
| `1` | Erro genérico |
| `2` | Warning (parcialmente bem-sucedido) |
| `3` | Autenticação necessária |

### 4. Output Padrão

#### Sucesso (stdout)

```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "target": "notebooklm",
    "synced": [
      {"file": "README.md", "status": "uploaded", "id": "abc123"},
      {"file": "docs/guide.md", "status": "updated", "id": "def456"}
    ],
    "skipped": [
      {"file": "large-file.pdf", "reason": "exceeds_size_limit"}
    ],
    "summary": {
      "total": 3,
      "synced": 2,
      "skipped": 1,
      "errors": 0
    }
  },
  "id": "sync-123456"
}
```

#### Erro (stderr)

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32030,
    "message": "Authentication failed",
    "data": {
      "details": "OAuth token expired",
      "instructions": "Run: /sync-to-notebooklm --auth",
      "context": "notebooklm-auth"
    }
  },
  "id": "sync-123456"
}
```

---

## SKILL.md Obrigatório

Todo sync skill DEVE ter um `SKILL.md` com frontmatter:

```yaml
---
name: sync-to-{target}
version: X.Y.Z
description: Descrição do skill
author: Nome
created: YYYY-MM-DD
status: stub|alpha|beta|stable
dependencies:
  - sync-orchestrator
triggers:
  - palavras que ativam o skill
---
```

---

## Métodos da Interface

### 1. `sync(files, options)`

**Propósito**: Sincronizar arquivos para o target.

**Parâmetros**:
- `files`: Lista de paths ou padrões glob
- `options`: Objeto com flags e configurações

**Retorno**: SyncResult

### 2. `status()`

**Propósito**: Verificar status da conexão e credenciais.

**Retorno**: StatusResult

### 3. `list(options)`

**Propósito**: Listar itens já sincronizados no target.

**Retorno**: ListResult

### 4. `diff(files, options)`

**Propósito**: Comparar local vs remote.

**Retorno**: DiffResult

### 5. `auth(options)`

**Propósito**: Autenticar ou re-autenticar.

**Retorno**: AuthResult

---

## Integração com sync-orchestrator

### Manifest Schema

O sync-orchestrator usa manifest YAML para coordenar:

```yaml
# sync-manifest.yaml
version: "1.0"
name: "project-docs-sync"

targets:
  - name: github
    skill: sync-to-git
    config:
      remote: origin
      branch: main
    include:
      - "**/*.md"
      - "**/*.txt"
    exclude:
      - "node_modules/**"

  - name: notebooklm
    skill: sync-to-notebooklm
    config:
      notebook: "project-notebook-id"
    include:
      - "docs/**/*.md"
      - "README.md"
    depends_on:
      - github  # Só executa após github

  - name: confluence
    skill: sync-to-confluence
    config:
      space: "PROJ"
      parent_page: "Documentation"
    include:
      - "docs/public/**/*.md"
```

### Eventos

Todo skill DEVE emitir eventos para o orchestrator:

| Evento | Quando |
|--------|--------|
| `sync:start` | Início da sincronização |
| `sync:progress` | A cada arquivo processado |
| `sync:complete` | Conclusão com sucesso |
| `sync:error` | Erro durante sync |
| `sync:warning` | Warning (não fatal) |

---

## Error Handling

### Ranges de Error Codes

Cada skill tem um range reservado:

| Skill | Range |
|-------|-------|
| sync-to-git | `-32010` a `-32019` |
| sync-orchestrator | `-32020` a `-32029` |
| sync-to-notebooklm | `-32030` a `-32039` |
| sync-to-confluence | `-32040` a `-32049` |
| Reservado | `-32050` a `-32099` |

Ver: [Error Codes Registry](~/.claude/docs/error-codes-registry.md)

### Recovery Pattern

```
1. Skill detecta erro
2. Emite JSON error para stderr
3. Emite mensagem humana (se não --json)
4. Retorna exit code apropriado
5. Orchestrator lê stderr
6. Orchestrator executa recovery baseado em "instructions"
```

---

## Configuração

### Hierarquia de Config

1. CLI flags (maior prioridade)
2. Arquivo especificado via `--config`
3. `.sync-{target}.json` no projeto
4. `~/.claude/config/{target}.json`
5. Defaults do skill (menor prioridade)

### Schema de Config

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "auth": {
      "type": "object",
      "properties": {
        "method": {"enum": ["oauth2", "api_key", "token"]},
        "credentials_file": {"type": "string"}
      }
    },
    "sync": {
      "type": "object",
      "properties": {
        "include_patterns": {"type": "array", "items": {"type": "string"}},
        "exclude_patterns": {"type": "array", "items": {"type": "string"}},
        "max_file_size_mb": {"type": "number"}
      }
    },
    "target_specific": {
      "type": "object",
      "description": "Configurações específicas do target"
    }
  }
}
```

---

## Testing

Todo skill DEVE incluir:

1. **Unit tests**: Para cada método da interface
2. **Integration tests**: Com target real (ou mock)
3. **Dry-run verification**: Garantir que dry-run não modifica nada
4. **Error scenarios**: Testar todos os error codes

---

## Versionamento

Skills seguem Semver:

| Mudança | Increment |
|---------|-----------|
| Breaking change na interface | MAJOR |
| Nova funcionalidade compatível | MINOR |
| Bug fix | PATCH |

---

## Checklist de Implementação

Para criar novo sync skill:

- [ ] Criar diretório `~/.claude/skills/sync-to-{target}/`
- [ ] Criar `SKILL.md` com frontmatter
- [ ] Implementar flags obrigatórias
- [ ] Implementar métodos da interface
- [ ] Registrar error codes no registry
- [ ] Criar config schema
- [ ] Escrever testes
- [ ] Documentar no README
- [ ] Registrar no sync-orchestrator

---

## Referências

- [sync-orchestrator skill](~/.claude/skills/sync-orchestrator/)
- [sync-to-git skill](~/.claude/skills/sync-to-git/)
- [Error Codes Registry](~/.claude/docs/error-codes-registry.md)
- [MCP-JSON-RPC Protocol](~/.claude/docs/mcp-jsonrpc-errors.md)

---

*Versão: 1.0.0 | Criado: 2026-01-23 | Autor: Claude-Code*
