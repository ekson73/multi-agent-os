#!/usr/bin/env bash
# Bootstrap environment for multi-agent-os
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: must be run inside a git repository."
    exit 1
}
cd "$REPO_ROOT"

echo "Iniciando Bootstrap do multi-agent-os..."

# 1. Configurar git hooks (mandatory for governance)
if [ ! -d ".githooks" ]; then
    echo "ERROR: .githooks/ directory not found. Governance hooks are mandatory."
    exit 1
fi
git config core.hooksPath .githooks
find .githooks -type f -exec chmod +x {} +
echo "Git hooks configurados (.githooks/)"

# 2. Configurar worktree dir
mkdir -p .worktrees
echo "Diretorio de worktrees criado (.worktrees/)"

# 3. Aliases
git config alias.wt "worktree"
echo "Alias 'git wt' configurado para 'git worktree'"

echo "Bootstrap finalizado com sucesso."
