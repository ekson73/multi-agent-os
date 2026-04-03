#!/usr/bin/env bash
# Bootstrap environment for multi-agent-os
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: must be run inside a git repository."
    exit 1
}
cd "$REPO_ROOT"

echo "Iniciando Bootstrap do multi-agent-os..."

# 1. Configurar git hooks
if [ -d ".githooks" ]; then
    git config core.hooksPath .githooks
    find .githooks -type f -exec chmod +x {} +
    echo "Git hooks configurados (.githooks/)"
fi

# 2. Configurar worktree dir
mkdir -p .worktrees
echo "Diretorio de worktrees criado (.worktrees/)"

# 3. Aliases
git config alias.wt "worktree"
echo "Alias 'git wt' configurado para 'git worktree'"

echo "Bootstrap finalizado com sucesso."
