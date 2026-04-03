#!/usr/bin/env bash
# Bootstrap environment for multi-agent-os

set -e
echo "🚀 Iniciando Bootstrap do multi-agent-os..."

# 1. Configurar git hooks
if [ -d ".githooks" ]; then
    git config core.hooksPath .githooks
    chmod +x .githooks/* || true
    echo "✅ Git hooks configurados (.githooks/)"
fi

# 2. Configurar worktree dir
mkdir -p .worktrees
echo "✅ Diretório de worktrees criado (.worktrees/)"

# 3. Aliases
git config alias.wt "worktree"
echo "✅ Alias 'git wt' configurado para 'git worktree'"

echo "🎉 Bootstrap finalizado com sucesso."
