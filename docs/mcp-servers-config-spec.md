# MCP Servers Configuration Specification

> **Versão**: 1.0.0 (2026-01-26)
> **Status**: Aprovado
> **Autor**: Claude Opus 4.5 + Emilson Moraes
> **Rule relacionada**: `~/.claude/rules/mcp-servers-config.md`

---

## 1. Propósito

Definir arquitetura para versionamento seguro de configurações MCP (Model Context Protocol) servers, separando templates públicos de secrets privados.

### 1.1 Problema Resolvido

| Problema | Impacto | Solução |
|----------|---------|---------|
| Secrets em `~/.claude.json` não versionados | Perda em reinstalação | Template + secrets separados |
| Credenciais expostas se commitar config | Vazamento de secrets | Gitignore para `*secret*` |
| Replicação manual em nova máquina | Erro humano, inconsistência | Script automatizado |

### 1.2 Escopo

| Inclui | Não inclui |
|--------|------------|
| MCP servers com secrets (tokens, passwords) | Configurações do Claude Code UI |
| Template com placeholders | Plugins/marketplaces (já versionados) |
| Script de aplicação | Autenticação OAuth (browser-based) |

---

## 2. Arquitetura

### 2.1 Visão Geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUXO DE CONFIGURAÇÃO                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐                       │
│  │ mcp-servers      │    │ mcp-servers      │                       │
│  │ .template.json   │ +  │ .secrets.json    │                       │
│  │ (versionado)     │    │ (gitignored)     │                       │
│  └────────┬─────────┘    └────────┬─────────┘                       │
│           │                       │                                 │
│           └───────────┬───────────┘                                 │
│                       ▼                                             │
│           ┌──────────────────────┐                                  │
│           │ apply-mcp-config.sh  │                                  │
│           │ (substitui ${VARS})  │                                  │
│           └──────────┬───────────┘                                  │
│                      ▼                                              │
│           ┌──────────────────────┐                                  │
│           │   ~/.claude.json     │                                  │
│           │   .mcpServers        │                                  │
│           └──────────────────────┘                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Componentes

| Arquivo | Localização | Git | Propósito |
|---------|-------------|-----|-----------|
| `mcp-servers.template.json` | `~/.claude/personal/dotclaude-configs/` | Commitado | Estrutura com placeholders |
| `mcp-servers.secrets.json` | `~/.claude/personal/dotclaude-configs/` | Ignorado | Valores dos secrets |
| `apply-mcp-config.sh` | `~/.claude/personal/dotclaude-configs/scripts/` | Commitado | Merge template + secrets |
| `~/.claude.json` | `~/` | N/A | Config final aplicada |

### 2.3 Hierarquia de Prioridade

```
1. ~/.claude.json (user-level)     ← MCP servers vivem aqui
2. .claude.json (project-level)    ← Override por projeto (se necessário)
```

---

## 3. Formato dos Arquivos

### 3.1 Template (`mcp-servers.template.json`)

```json
{
  "_comment": "Template para MCP Servers. Secrets em mcp-servers.secrets.json",
  "_usage": "Execute: ./scripts/apply-mcp-config.sh",
  
  "nome-do-server": {
    "type": "stdio|http",
    "command": "comando ou ${HOME}/path",
    "args": ["arg1", "arg2"],
    "env": {
      "VAR_PUBLICA": "valor-literal",
      "VAR_SECRETA": "${PLACEHOLDER_NAME}"
    }
  },
  
  "server-http-exemplo": {
    "type": "http",
    "url": "https://api.example.com/mcp?apiKey=${API_KEY_PLACEHOLDER}",
    "headers": {
      "Authorization": "Bearer ${TOKEN_PLACEHOLDER}"
    }
  }
}
```

#### Convenções de Placeholders

| Padrão | Uso | Exemplo |
|--------|-----|---------|
| `${HOME}` | Variável de ambiente do sistema | `${HOME}/Projects/...` |
| `${NOME_SERVICO_TIPO}` | Secret específico | `${BITBUCKET_APP_PASSWORD}` |
| Valor literal | Config pública | `"npx"`, `"mcp"`, `"start"` |

### 3.2 Secrets (`mcp-servers.secrets.json`)

```json
{
  "_comment": "SECRETS - NÃO COMMITAR! Este arquivo está no .gitignore",
  
  "BITBUCKET_USERNAME": "seu-usuario",
  "BITBUCKET_APP_PASSWORD": "seu-app-password",
  "REF_TOOLS_API_KEY": "ref-xxxxx",
  "ZAPIER_MCP_TOKEN": "token-base64"
}
```

#### Regras de Nomenclatura

| Padrão | Descrição | Exemplo |
|--------|-----------|---------|
| `{SERVICO}_{TIPO}` | Identificador único | `BITBUCKET_APP_PASSWORD` |
| SCREAMING_SNAKE_CASE | Convenção de constantes | `REF_TOOLS_API_KEY` |
| Sem prefixo `$` | Apenas o nome | `ZAPIER_MCP_TOKEN` (não `$ZAPIER_MCP_TOKEN`) |

---

## 4. Categorização de MCP Servers

### 4.1 Por Tipo de Autenticação

| Categoria | Autenticação | Versionável? | Exemplo |
|-----------|--------------|--------------|---------|
| **Public** | Nenhuma | Sim (completo) | `sequential-thinking-mcp` |
| **OAuth Browser** | Via navegador | Sim (sem secret) | `atlasian-rovo-mcp`, `exa-mcp` |
| **API Key** | Token estático | Template + secret | `ref-tools-mcp`, `zapier-mcp` |
| **App Password** | Credencial de serviço | Template + secret | `vekops-mcp-hub` |

### 4.2 Por Tipo de Conexão

| Tipo | Características | Campos Requeridos |
|------|-----------------|-------------------|
| `stdio` | Processo local | `command`, `args`, `env` (opcional) |
| `http` | Endpoint remoto | `url`, `headers` (opcional) |

---

## 5. Processo de Aplicação

### 5.1 Algoritmo do Script

```
1. VALIDAR arquivos necessários existem
2. LER secrets.json → extrair pares chave/valor
3. LER template.json → string
4. SUBSTITUIR ${HOME} → valor real
5. PARA CADA secret:
   - SUBSTITUIR ${CHAVE} → valor
6. VERIFICAR placeholders não substituídos
7. BACKUP ~/.claude.json
8. MERGE mcpServers no ~/.claude.json
9. SALVAR
```

### 5.2 Comandos

```bash
# Dry-run (ver resultado sem aplicar)
~/.claude/personal/dotclaude-configs/scripts/apply-mcp-config.sh --dry-run

# Aplicar
~/.claude/personal/dotclaude-configs/scripts/apply-mcp-config.sh

# Verificar resultado
claude mcp list
```

---

## 6. Segurança

### 6.1 Proteções Implementadas

| Camada | Mecanismo | Arquivo Protegido |
|--------|-----------|-------------------|
| Git | `.gitignore` com `*secret*` | `mcp-servers.secrets.json` |
| Backup | Automático antes de aplicar | `~/.claude.json.backup.*` |
| Validação | Alerta de placeholders não substituídos | Template incompleto |

### 6.2 Checklist de Segurança

Antes de commitar:

- [ ] `mcp-servers.secrets.json` NÃO está staged (`git status`)
- [ ] Template não contém valores reais de secrets
- [ ] Placeholders seguem padrão `${NOME}`

### 6.3 Rotação de Secrets

```bash
# 1. Atualizar secret no arquivo local
vim ~/.claude/personal/dotclaude-configs/mcp-servers.secrets.json

# 2. Reaplicar configuração
~/.claude/personal/dotclaude-configs/scripts/apply-mcp-config.sh

# 3. Verificar
claude mcp list
```

---

## 7. Replicação para Nova Máquina

### 7.1 Workflow Completo

```bash
# 1. Clone do repositório personal
git clone git@github.com:vek-emilsonmoraes-pws/dot-claude.git ~/.claude/personal

# 2. Setup symlinks (configs gerais)
~/.claude/personal/dotclaude-configs/scripts/setup-symlinks.sh

# 3. Criar arquivo de secrets (manual - secrets não vêm do git)
cat > ~/.claude/personal/dotclaude-configs/mcp-servers.secrets.json << 'EOF'
{
  "_comment": "Preencher com seus secrets",
  "BITBUCKET_USERNAME": "seu-usuario",
  "BITBUCKET_APP_PASSWORD": "obter-do-bitbucket",
  "REF_TOOLS_API_KEY": "obter-do-ref-tools",
  "ZAPIER_MCP_TOKEN": "obter-do-zapier"
}
EOF

# 4. Aplicar configuração MCP
~/.claude/personal/dotclaude-configs/scripts/apply-mcp-config.sh

# 5. Verificar
claude mcp list
```

### 7.2 Obtenção de Secrets

| Secret | Onde Obter |
|--------|------------|
| `BITBUCKET_APP_PASSWORD` | Bitbucket > Settings > App passwords |
| `REF_TOOLS_API_KEY` | ref.tools > Dashboard > API Keys |
| `ZAPIER_MCP_TOKEN` | Zapier > Settings > MCP Integration |

---

## 8. Troubleshooting

### 8.1 Problemas Comuns

| Sintoma | Causa | Solução |
|---------|-------|---------|
| `Placeholder não substituído: ${X}` | Secret faltando | Adicionar em `secrets.json` |
| `MCP server não conecta` | Secret inválido | Verificar/rotacionar credential |
| `jq: parse error` | JSON inválido | Validar com `jq . arquivo.json` |

### 8.2 Diagnóstico

```bash
# Verificar template é JSON válido
jq . ~/.claude/personal/dotclaude-configs/mcp-servers.template.json

# Verificar secrets é JSON válido (cuidado: mostra secrets!)
jq . ~/.claude/personal/dotclaude-configs/mcp-servers.secrets.json

# Ver config atual aplicada
jq '.mcpServers' ~/.claude.json

# Testar conexão MCP
claude mcp list
```

---

## 9. Extensibilidade

### 9.1 Adicionar Novo MCP Server

1. **Editar template** (`mcp-servers.template.json`):
   ```json
   "novo-server": {
     "type": "http",
     "url": "https://api.novo.com/mcp?key=${NOVO_API_KEY}"
   }
   ```

2. **Adicionar secret** (`mcp-servers.secrets.json`):
   ```json
   "NOVO_API_KEY": "valor-real"
   ```

3. **Aplicar**:
   ```bash
   ./scripts/apply-mcp-config.sh
   ```

4. **Commitar** (apenas template):
   ```bash
   git add mcp-servers.template.json
   git commit -m "feat(mcp): add novo-server"
   ```

### 9.2 Override por Projeto

Para configuração específica de projeto, usar `.claude.json` no diretório do projeto:

```json
{
  "mcpServers": {
    "projeto-especifico-mcp": {
      "type": "stdio",
      "command": "./local-mcp-server.py"
    }
  }
}
```

---

## 10. Referências

| Documento | Localização | Relação |
|-----------|-------------|---------|
| Rule (enforcement) | `~/.claude/rules/mcp-servers-config.md` | Auto-load |
| README (uso) | `~/.claude/personal/dotclaude-configs/README.md` | Quick start |
| dotclaude-configs | `~/.claude/personal/dotclaude-configs/` | Implementação |
| CLAUDE.md [C06] | `~/.claude/CLAUDE.md` | AI-Native Environment |

---

## Changelog

| Versão | Data | Autor | Mudança |
|--------|------|-------|---------|
| 1.0.0 | 2026-01-26 | Claude + Emilson | Versão inicial |

---

*Spec completa | Auto-propagada de sessão 2026-01-26*
