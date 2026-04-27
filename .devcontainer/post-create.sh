#!/bin/bash
# SPDX-License-Identifier: MIT
# ==========================================================================
# post-create.sh — Runs once after container creation (postCreateCommand)
# Syncs project dependencies, installs user-level tools, and shows versions
# ==========================================================================
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${SCRIPT_DIR}/scripts/lib"
# shellcheck source=/dev/null
source "${_LIB_DIR}/logging.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/retry.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/version.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/workspace.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/manifest.sh"

copilot_cli_path() {
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"

    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/copilot" ]; then
        printf '%s\n' "$npm_prefix/bin/copilot"
        return 0
    fi

    command -v copilot 2>/dev/null
}

copilot_version() {
    local copilot_bin
    copilot_bin="$(copilot_cli_path)" || return 1
    "$copilot_bin" --version 2>&1 | head -1
}

ollama_client_version() {
    local version_output
    local client_version

    if ! command -v ollama >/dev/null 2>&1; then
        return 1
    fi

    version_output="$(ollama --version 2>&1 || true)"
    [ -n "$version_output" ] || return 1

    # Prefer client version when Ollama reports both server and client versions.
    client_version="$(printf '%s\n' "$version_output" | awk '/client version is/ { print $NF; exit }')"
    if [ -n "$client_version" ]; then
        printf 'client %s\n' "$client_version"
        return 0
    fi

    printf '%s\n' "$version_output" | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1
}

workspace_npm_version() {
    local workspace_dir="$1"
    node -p "const packageManager = require(process.argv[1]).packageManager || ''; packageManager.startsWith('npm@') ? packageManager.slice(4) : ''" "$workspace_dir/package.json"
}

echo "=== Post-create setup ==="

# ------------------------------------------------------------------
# Refresh version pins and install update-tools.sh to PATH
# ------------------------------------------------------------------
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ">>> Refreshing package.json and pyproject.toml version pins..."
if ! refresh_package_manager_pin "$WORKSPACE_DIR"; then
    echo "WARNING: npm packageManager pin failed to refresh"
fi

if ! refresh_package_json_dependency_pins "$WORKSPACE_DIR"; then
    echo "WARNING: package.json dependency pins failed to refresh"
fi

if ! refresh_pyproject_dependency_pins "$WORKSPACE_DIR"; then
    echo "WARNING: pyproject.toml dependency pins failed to refresh"
fi

echo ">>> Refreshing devcontainer runtime feature pins for the next rebuild..."
if ! refresh_node_runtime_feature_pin "$WORKSPACE_DIR"; then
    echo "WARNING: Node.js feature pin failed to refresh"
fi

if ! refresh_python_runtime_feature_pin "$WORKSPACE_DIR"; then
    echo "WARNING: Python feature pin failed to refresh"
fi

echo ">>> Installing shellcheck for local shell script linting..."
sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends shellcheck

WORKSPACE_NPM_VERSION="$(workspace_npm_version "$WORKSPACE_DIR")"
sudo install -m 755 "$SCRIPT_DIR/scripts/update-tools.sh" /usr/local/bin/update-tools.sh

if [ -n "$WORKSPACE_NPM_VERSION" ] && [ "$(npm --version)" != "$WORKSPACE_NPM_VERSION" ]; then
    echo ">>> Aligning npm version with packageManager..."
    npm install -g "npm@${WORKSPACE_NPM_VERSION}"
    hash -r
fi

# ------------------------------------------------------------------
# Project-local npm / Python dependencies
# ------------------------------------------------------------------
echo ">>> Refreshing project npm lockfile to the latest allowed versions..."
if ! retry 3 npm update --package-lock-only --prefix "$WORKSPACE_DIR"; then
    echo "WARNING: Project npm lockfile failed to refresh"
elif ! retry 3 npm ci --prefix "$WORKSPACE_DIR"; then
    echo "WARNING: Project npm dependencies failed to install"
fi

echo ">>> Refreshing project Python lockfile to the latest allowed versions..."
if ! (cd "$WORKSPACE_DIR" && uv lock --upgrade); then
    echo "WARNING: Project Python lockfile failed to refresh"
elif ! (cd "$WORKSPACE_DIR" && UV_LINK_MODE=copy uv sync --dev); then
    echo "WARNING: Project Python dependencies failed to sync"
fi

# ------------------------------------------------------------------
# Global AI CLIs
# ------------------------------------------------------------------
echo ">>> Installing AI CLI tools..."
if ! retry 3 env npm_config_ignore_scripts=false npm install -g @openai/codex@0.121.0 @github/copilot@1.0.28 opencode-ai@1.14.28; then
    echo "WARNING: Some AI CLI npm packages failed to install"
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "WARNING: Claude Code still not found after on-create fallback install."
    echo "Run 'update-tools.sh claude-code' or rebuild the container."
fi

# ------------------------------------------------------------------
# Tool version reporting
# ------------------------------------------------------------------
echo ""
echo "--- Installed tool versions ---"
echo "Git:        $(git --version 2>/dev/null || echo 'N/A')"
echo "Azure CLI:  $(az version --query '"azure-cli"' --output tsv 2>/dev/null || echo 'N/A')"
echo "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'N/A')"
echo "Docker:     $(docker --version 2>/dev/null || echo 'N/A')"
echo "Compose:    $(docker compose version 2>/dev/null || echo 'N/A')"
echo "Python:     $(python3 --version 2>/dev/null || echo 'N/A')"
echo "uv:         $(uv --version 2>/dev/null || echo 'N/A')"
echo "Node.js:    $(node --version 2>/dev/null || echo 'N/A')"
echo "npm:        $(npm --version 2>/dev/null || echo 'N/A')"
echo "TypeScript: $(workspace_node_tool_version "$WORKSPACE_DIR" tsc 2>/dev/null || echo 'N/A')"
echo "Vite:       $(workspace_node_tool_version "$WORKSPACE_DIR" vite 2>/dev/null || echo 'N/A')"
echo "Vitest:     $(workspace_node_tool_version "$WORKSPACE_DIR" vitest 2>/dev/null || echo 'N/A')"
echo "Biome:      $(workspace_node_tool_version "$WORKSPACE_DIR" biome 2>/dev/null || echo 'N/A')"
echo "Turbo:      $(workspace_node_tool_version "$WORKSPACE_DIR" turbo 2>/dev/null || echo 'N/A')"
echo "pytest:     $(workspace_python_tool_version "$WORKSPACE_DIR" pytest 2>/dev/null || echo 'N/A')"
echo "Ollama:     $(ollama_client_version 2>/dev/null || echo 'installed')"
echo ""
echo "--- AI CLI tools ---"
copilot_version_value="$(copilot_version 2>/dev/null || true)"
echo "Claude Code:     $(claude --version 2>/dev/null || echo 'N/A')"
echo "OpenAI Codex:    $(codex --version 2>/dev/null || echo 'N/A')"
if [ -n "$copilot_version_value" ]; then
    echo "GitHub Copilot:  $copilot_version_value"
else
    echo "GitHub Copilot:  N/A"
fi
echo "OpenCode:        $(opencode --version 2>/dev/null || echo 'N/A')"

echo ""
echo "=== Post-create setup complete ==="
