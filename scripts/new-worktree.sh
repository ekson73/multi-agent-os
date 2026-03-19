#!/usr/bin/env bash

# Criação automatizada de Git Worktrees padronizada para agents e humanos
# Exemplo de uso: ./scripts/new-worktree.sh feat/PROJ-123-minha-feature

if [ -z "$1" ]; then
  echo "❌ Uso: ./scripts/new-worktree.sh <nome-da-branch>"
  exit 1
fi

BRANCH_NAME=$1
# Transforma barras em hífens para dar nome amigável ao diretório
DIR_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')

# Mente de Tomé (Desconfiada): Verifica se a raiz do repositório está correta
if [ ! -d ".git" ] && [ ! -f ".git" ]; then
    echo "❌ Erro estrutural: Este script deve ser executado da raiz do repositório Git."
    exit 1
fi

# Mente de Tomé: Garante que o .gitignore tem a exclusão de worktrees
if ! grep -q "^.worktrees" .gitignore 2>/dev/null; then
    echo ".worktrees/" >> .gitignore
    echo "🛡️ Adicionado '.worktrees/' ao .gitignore silenciosamente."
fi

mkdir -p .worktrees
WORKTREE_PATH=".worktrees/$DIR_NAME"

if [ -d "$WORKTREE_PATH" ]; then
    echo "⚠️ Aviso: O Worktree em '$WORKTREE_PATH' já existe. Abortando criação para prevenir sobreposição (Agent Collision)."
    exit 1
fi

echo "🔧 Mapeando worktree isolada para '$BRANCH_NAME' em './$WORKTREE_PATH'..."
# Usa o git worktree nativo criando a branch
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"

# Permite ao agente/humano entrar nativamente na pasta
echo "✅ Worktree provisionada com sucesso sob as leis da Governança Híbrida!"
echo "👉 cd $WORKTREE_PATH"
