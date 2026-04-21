#!/bin/bash
# SPDX-License-Identifier: MIT
# ============================================================================
# Dev Container tool update script
# Updates tools individually or in bulk without rebuilding the container
#
# Usage:
#   update-tools.sh              # Update the default tool set (excludes project deps)
#   update-tools.sh --list       # Show supported update targets
#   update-tools.sh <tool> ...   # Update only the selected tools
#
# Examples:
#   update-tools.sh uv claude-code
#   update-tools.sh npm-tools
#   update-tools.sh node-deps-check
#   update-tools.sh python-deps-check
#   update-tools.sh --all
# ============================================================================
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${SCRIPT_DIR}/lib"
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

print_already_current() {
    local version_output="$1"
    echo -e "${GREEN}  Already up to date (${version_output})${NC}"
}

apt_installed_version() {
    dpkg-query -W -f='${Version}\n' "$1" 2>/dev/null || true
}

apt_candidate_version() {
    apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ { print $2; exit }'
}

npm_package_latest_version() {
    npm view "$1" version 2>/dev/null | head -1
}

github_latest_release_tag() {
    curl --silent --show-error --location --output /dev/null --write-out '%{url_effective}' "$1" | awk -F/ '{ print $NF }'
}

nvm_latest_lts_version() {
    nvm ls-remote --lts 2>/dev/null | awk '$1 ~ /^v[0-9]/ { version = $1 } END { print version }'
}

uv_latest_version() {
    normalize_version "$(github_latest_release_tag 'https://github.com/astral-sh/uv/releases/latest')"
}

ollama_latest_version() {
    normalize_version "$(github_latest_release_tag 'https://github.com/ollama/ollama/releases/latest')"
}

ollama_installed_version() {
    local version_output
    local client_version

    version_output="$(ollama --version 2>&1 || true)"
    [ -n "$version_output" ] || return 1

    client_version="$(printf '%s\n' "$version_output" | awk '/client version is/ { print $NF; exit }')"
    if [ -n "$client_version" ]; then
        printf '%s\n' "$client_version"
        return 0
    fi

    normalize_version "$version_output"
}

claude_code_latest_version() {
    curl -fsSL 'https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/latest' | head -1
}

ollama_architecture() {
    case "$(uname -m)" in
        x86_64) printf '%s\n' 'amd64' ;;
        aarch64|arm64) printf '%s\n' 'arm64' ;;
        *)
            echo -e "${RED}  Unsupported Ollama architecture: $(uname -m)${NC}" >&2
            return 1
            ;;
    esac
}

install_ollama_binary() {
    local arch
    local version="$1"
    local install_dir="/usr/local"
    local archive_url

    arch="$(ollama_architecture)" || return 1
    archive_url="https://ollama.com/download/ollama-linux-${arch}.tar.zst"

    if [ -n "$version" ]; then
        archive_url="${archive_url}?version=${version}"
    fi

    sudo install -d -m755 "${install_dir}/bin" "${install_dir}/lib/ollama"
    sudo rm -rf "${install_dir}/lib/ollama"
    sudo install -d -m755 "${install_dir}/lib/ollama"

    curl --fail --show-error --location --progress-bar "$archive_url" | \
        zstd -d | sudo tar -xf - -C "$install_dir"
}

project_npm_version() {
    local root_dir

    root_dir="$(find_workspace_root)" || return 1
    workspace_npm_version "$root_dir"
}

project_node_tool_path() {
    local tool_name="$1"
    local root_dir

    root_dir="$(find_workspace_root)" || return 1
    workspace_node_tool_path "$root_dir" "$tool_name"
}

project_node_tool_version() {
    local tool_name="$1"
    local tool_path

    tool_path="$(project_node_tool_path "$tool_name")" || return 1
    "$tool_path" --version 2>/dev/null | head -1
}

project_python_tool_version() {
    local tool_name="$1"
    local root_dir

    root_dir="$(find_workspace_root)" || return 1
    workspace_python_tool_version "$root_dir" "$tool_name"
}

require_workspace_root_with_message() {
    if ! find_workspace_root >/dev/null 2>&1; then
        echo -e "${YELLOW}  No project workspace found from current directory.${NC}"
        echo -e "${YELLOW}  Run this command from the repository root or one of its subdirectories.${NC}"
        return 1
    fi
}

# Default update targets for `update-tools.sh` and `update-tools.sh --all`.
# Project dependency refreshes remain available as explicit targets.
DEFAULT_TOOL_NAMES=(
    azure-cli
    github-cli
    git
    docker
    node
    npm
    python
    uv
    ollama
    claude-code
    codex
    copilot
)

# --------------------------------------------------------------------------
# Per-tool update functions
# --------------------------------------------------------------------------

update_azure_cli() {
    echo -e "${CYAN}[azure-cli]${NC} Updating Azure CLI..."
    sudo apt-get update -qq
    local installed_version
    local candidate_version
    installed_version="$(apt_installed_version azure-cli)"
    candidate_version="$(apt_candidate_version azure-cli)"

    if [ -n "$installed_version" ] && [ -n "$candidate_version" ] && [ "$candidate_version" != "(none)" ] && [ "$installed_version" = "$candidate_version" ]; then
        print_already_current "azure-cli ${installed_version}"
    else
        sudo apt-get install -y --only-upgrade azure-cli 2>/dev/null \
            || pip install --upgrade azure-cli 2>/dev/null \
            || echo -e "${YELLOW}  Azure CLI is managed by devcontainer feature. Rebuild to update.${NC}"
    fi
    echo -e "${GREEN}  $(az version --query '"azure-cli"' --output tsv 2>/dev/null || echo 'N/A')${NC}"
}

update_github_cli() {
    echo -e "${CYAN}[github-cli]${NC} Updating GitHub CLI..."
    sudo apt-get update -qq
    local installed_version
    local candidate_version
    installed_version="$(apt_installed_version gh)"
    candidate_version="$(apt_candidate_version gh)"

    if [ -n "$installed_version" ] && [ -n "$candidate_version" ] && [ "$candidate_version" != "(none)" ] && [ "$installed_version" = "$candidate_version" ]; then
        print_already_current "gh ${installed_version}"
    else
        sudo apt-get install -y --only-upgrade gh 2>/dev/null \
            || echo -e "${YELLOW}  GitHub CLI is managed by devcontainer feature. Rebuild to update.${NC}"
    fi
    echo -e "${GREEN}  $(gh --version | head -1)${NC}"
}

update_git() {
    echo -e "${CYAN}[git]${NC} Updating Git..."
    sudo apt-get update -qq
    local installed_version
    local candidate_version
    installed_version="$(apt_installed_version git)"
    candidate_version="$(apt_candidate_version git)"

    if [ -n "$installed_version" ] && [ -n "$candidate_version" ] && [ "$candidate_version" != "(none)" ] && [ "$installed_version" = "$candidate_version" ]; then
        print_already_current "git ${installed_version}"
    else
        sudo apt-get install -y --only-upgrade git
    fi
    echo -e "${GREEN}  $(git --version)${NC}"
}

update_docker() {
    echo -e "${CYAN}[docker]${NC} Docker is managed by the host or devcontainer feature."
    echo -e "${YELLOW}  Rebuild the container or update Docker on the host to upgrade.${NC}"
    echo -e "${GREEN}  $(docker --version)${NC}"
}

update_node() {
    echo -e "${CYAN}[node]${NC} Updating Node.js..."
    local root_dir=""
    local feature_update_status=""

    if find_workspace_root >/dev/null 2>&1; then
        root_dir="$(find_workspace_root)"
        if feature_update_status="$(refresh_node_runtime_feature_pin "$root_dir")"; then
            if [ "$feature_update_status" = "updated" ]; then
                echo -e "${GREEN}  Updated .devcontainer/devcontainer.json for the next rebuild.${NC}"
            fi
        else
            echo -e "${YELLOW}  Could not refresh the Node.js feature pin.${NC}"
        fi
    fi

    if command -v nvm &>/dev/null || [ -s "$HOME/.nvm/nvm.sh" ]; then
        # shellcheck source=/dev/null
        source "$HOME/.nvm/nvm.sh" 2>/dev/null || true
        local current_version
        local latest_lts_version
        current_version="$(node --version 2>/dev/null || true)"
        latest_lts_version="$(nvm_latest_lts_version)"

        if skip_if_same_version "$current_version" "$latest_lts_version"; then
            :
        else
            nvm install --lts --reinstall-packages-from=current
            nvm alias default lts/*
        fi
    else
        echo -e "${YELLOW}  Node.js is managed by devcontainer feature. Rebuild to update.${NC}"
    fi
    echo -e "${GREEN}  Node.js $(node --version), npm $(npm --version)${NC}"
}

update_npm() {
    echo -e "${CYAN}[npm]${NC} Updating npm..."
    local desired_version
    local current_version
    local root_dir=""

    if find_workspace_root >/dev/null 2>&1; then
        root_dir="$(find_workspace_root)"
        if ! refresh_package_manager_pin "$root_dir"; then
            echo -e "${YELLOW}  Could not refresh packageManager in package.json.${NC}"
        fi
    fi

    desired_version="$(project_npm_version 2>/dev/null || true)"
    current_version="$(npm --version 2>/dev/null || true)"

    if [ -z "$desired_version" ]; then
        desired_version="$(npm_package_latest_version npm || true)"
    fi

    if skip_if_same_version "$current_version" "$desired_version"; then
        return 0
    fi

    if [ -n "$desired_version" ]; then
        npm install -g "npm@${desired_version}"
    else
        npm install -g npm@latest
    fi
    echo -e "${GREEN}  npm $(npm --version)${NC}"
}

sync_node_dependencies() {
    local root_dir
    require_workspace_root_with_message || return 1
    root_dir="$(find_workspace_root)"

    echo -e "${CYAN}[node-deps]${NC} Refreshing package.json dependency pins..."
    refresh_package_json_dependency_pins "$root_dir"
    echo -e "${CYAN}[node-deps]${NC} Refreshing npm lockfile to the latest allowed versions..."
    (cd "$root_dir" && npm update --package-lock-only)
    echo -e "${CYAN}[node-deps]${NC} Syncing project-local npm dependencies..."
    (cd "$root_dir" && npm ci)
    echo -e "${GREEN}  TypeScript $(project_node_tool_version tsc 2>/dev/null || echo 'N/A')${NC}"
    echo -e "${GREEN}  Vite $(project_node_tool_version vite 2>/dev/null || echo 'N/A')${NC}"
    echo -e "${GREEN}  Vitest $(project_node_tool_version vitest 2>/dev/null || echo 'N/A')${NC}"
    echo -e "${GREEN}  Biome $(project_node_tool_version biome 2>/dev/null || echo 'N/A')${NC}"
    echo -e "${GREEN}  Turbo $(project_node_tool_version turbo 2>/dev/null || echo 'N/A')${NC}"
}

check_node_dependencies() {
    require_workspace_root_with_message || return 1

    echo -e "${CYAN}[node-deps-check]${NC} Checking whether package.json dependencies need attention..."
    "${SCRIPT_DIR}/check-package-updates.sh"
}

update_python() {
    local root_dir=""
    local feature_update_status=""

    echo -e "${CYAN}[python]${NC} Python is managed by devcontainer feature."
    if find_workspace_root >/dev/null 2>&1; then
        root_dir="$(find_workspace_root)"
        if feature_update_status="$(refresh_python_runtime_feature_pin "$root_dir")"; then
            if [ "$feature_update_status" = "updated" ]; then
                echo -e "${GREEN}  Updated .devcontainer/devcontainer.json for the next rebuild.${NC}"
            fi
        else
            echo -e "${YELLOW}  Could not refresh the Python feature pin.${NC}"
        fi
    fi
    echo -e "${YELLOW}  Rebuild the container to update Python.${NC}"
    echo -e "${GREEN}  $(python3 --version)${NC}"
}

update_uv() {
    echo -e "${CYAN}[uv]${NC} Updating uv..."
    local current_version
    local desired_version
    current_version="$(uv --version 2>/dev/null || true)"
    desired_version="$(uv_latest_version || true)"

    if command -v uv &>/dev/null && [ -n "$desired_version" ] && skip_if_same_version "$current_version" "$desired_version"; then
        return 0
    fi

    if command -v uv &>/dev/null; then
        if [ -n "$desired_version" ]; then
            sudo uv self update "$desired_version" 2>/dev/null \
                || (curl -LsSf "https://releases.astral.sh/github/uv/releases/download/${desired_version}/uv-installer.sh" | sudo env UV_INSTALL_DIR=/usr/local/bin sh)
        else
            sudo uv self update 2>/dev/null \
                || (curl -LsSf "https://astral.sh/uv/install.sh" | sudo env UV_INSTALL_DIR=/usr/local/bin sh)
        fi
    else
        if [ -n "$desired_version" ]; then
            curl -LsSf "https://releases.astral.sh/github/uv/releases/download/${desired_version}/uv-installer.sh" | sudo env UV_INSTALL_DIR=/usr/local/bin sh
        else
            curl -LsSf "https://astral.sh/uv/install.sh" | sudo env UV_INSTALL_DIR=/usr/local/bin sh
        fi
    fi
    echo -e "${GREEN}  $(uv --version)${NC}"
}

sync_python_dependencies() {
    local root_dir
    require_workspace_root_with_message || return 1
    root_dir="$(find_workspace_root)"

    echo -e "${CYAN}[python-deps]${NC} Refreshing pyproject.toml dependency pins..."
    refresh_pyproject_dependency_pins "$root_dir"
    echo -e "${CYAN}[python-deps]${NC} Refreshing uv.lock to the latest allowed versions..."
    (cd "$root_dir" && uv lock --upgrade)
    echo -e "${CYAN}[python-deps]${NC} Syncing project-local Python dependencies..."
    (cd "$root_dir" && UV_LINK_MODE=copy uv sync --dev)
    echo -e "${GREEN}  pytest $(project_python_tool_version pytest 2>/dev/null || echo 'N/A')${NC}"
}

check_python_dependencies() {
    require_workspace_root_with_message || return 1

    echo -e "${CYAN}[python-deps-check]${NC} Checking whether Python dependencies need attention..."
    "${SCRIPT_DIR}/check-python-package-updates.sh"
}

update_ollama() {
    echo -e "${CYAN}[ollama]${NC} Updating Ollama..."
    local current_version
    local desired_version
    current_version="$(ollama_installed_version 2>/dev/null || true)"
    desired_version="$(ollama_latest_version || true)"

    if command -v ollama &>/dev/null && [ -n "$desired_version" ] && skip_if_same_version "$current_version" "$desired_version"; then
        return 0
    fi

    if ! command -v zstd &>/dev/null; then
        echo -e "${YELLOW}  zstd is required for the Ollama installer. Installing...${NC}"
        sudo apt-get update -qq && sudo apt-get install -y zstd
    fi
    install_ollama_binary "$desired_version"
    echo -e "${GREEN}  $(ollama --version 2>/dev/null || echo 'installed')${NC}"
}

update_claude_code() {
    echo -e "${CYAN}[claude-code]${NC} Updating Claude Code..."
    local current_version
    local desired_version
    current_version="$(claude --version 2>/dev/null || true)"
    desired_version="$(claude_code_latest_version || true)"

    if command -v claude &>/dev/null && [ -n "$desired_version" ] && skip_if_same_version "$current_version" "$desired_version"; then
        return 0
    fi

    curl -fsSL https://claude.ai/install.sh | bash -s -- "${desired_version:-latest}"
    echo -e "${GREEN}  $(claude --version 2>/dev/null || echo 'installed')${NC}"
}

update_codex() {
    echo -e "${CYAN}[codex]${NC} Updating OpenAI Codex CLI..."
    local current_version
    local latest_version
    current_version="$(codex --version 2>/dev/null || true)"
    latest_version="$(npm_package_latest_version @openai/codex || true)"

    if command -v codex &>/dev/null && skip_if_same_version "$current_version" "$latest_version"; then
        return 0
    fi

    npm install -g @openai/codex
    echo -e "${GREEN}  $(codex --version 2>/dev/null || echo 'installed')${NC}"
}

update_copilot() {
    echo -e "${CYAN}[copilot]${NC} Updating GitHub Copilot CLI..."
    local current_version
    local latest_version
    current_version="$(copilot_version 2>/dev/null || true)"
    latest_version="$(npm_package_latest_version @github/copilot || true)"

    if [ -n "$current_version" ] && skip_if_same_version "$current_version" "$latest_version"; then
        return 0
    fi

    npm_config_ignore_scripts=false npm install -g @github/copilot
    local copilot_version_value
    copilot_version_value="$(copilot_version 2>/dev/null || true)"
    if [ -n "$copilot_version_value" ]; then
        echo -e "${GREEN}  ${copilot_version_value}${NC}"
    else
        echo -e "${YELLOW}  installed, but not yet initialized${NC}"
    fi
}

# --------------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------------

show_list() {
    echo -e "${CYAN}=== Supported Update Targets ===${NC}"
    echo ""
    echo "  Infrastructure:"
    echo "    azure-cli      - Azure CLI"
    echo "    github-cli     - GitHub CLI"
    echo "    git            - Git"
    echo "    docker         - Docker (host-managed)"
    echo ""
    echo "  Runtimes:"
    echo "    node           - Refresh Node.js feature pin and update the current runtime when possible"
    echo "    npm            - npm"
    echo "    python         - Refresh Python feature pin for the next rebuild"
    echo ""
    echo "  Package Managers / Build:"
    echo "    uv             - uv (Python)"
    echo "    node-deps      - Refresh package.json pins, package-lock.json, and project-local Node.js dependencies"
    echo "    node-deps-check - Check whether package.json or installed Node.js deps need updates"
    echo "    python-deps    - Refresh pyproject.toml pins, uv.lock, and project-local Python dependencies"
    echo "    python-deps-check - Check whether Python dependency specs, lockfile, or env need updates"
    echo ""
    echo "  AI / LLM:"
    echo "    ollama         - Ollama"
    echo "    claude-code    - Claude Code"
    echo "    codex          - OpenAI Codex CLI"
    echo "    copilot        - GitHub Copilot CLI"
    echo ""
    echo -e "Usage: ${YELLOW}update-tools.sh <tool> [<tool> ...]${NC}"
    echo -e "Update all: ${YELLOW}update-tools.sh --all${NC}"
    echo -e "${YELLOW}Note:${NC} --all updates the default tool set only. Run ${YELLOW}update-tools.sh node-deps${NC} and/or ${YELLOW}update-tools.sh python-deps${NC} explicitly to refresh workspace dependencies."
}

show_versions() {
    local copilot_version_value
    copilot_version_value="$(copilot_version 2>/dev/null || true)"

    echo ""
    echo -e "${CYAN}=== Current Versions ===${NC}"
    echo "Git:             $(git --version 2>/dev/null || echo 'N/A')"
    echo "Azure CLI:       $(az version --query '"azure-cli"' --output tsv 2>/dev/null || echo 'N/A')"
    echo "GitHub CLI:      $(gh --version 2>/dev/null | head -1 || echo 'N/A')"
    echo "Docker:          $(docker --version 2>/dev/null || echo 'N/A')"
    echo "Docker Compose:  $(docker compose version 2>/dev/null || echo 'N/A')"
    echo "Node.js:         $(node --version 2>/dev/null || echo 'N/A')"
    echo "npm:             $(npm --version 2>/dev/null || echo 'N/A')"
    echo "Python:          $(python3 --version 2>/dev/null || echo 'N/A')"
    echo "uv:              $(uv --version 2>/dev/null || echo 'N/A')"
    echo "TypeScript:      $(project_node_tool_version tsc 2>/dev/null || echo 'N/A')"
    echo "Vite:            $(project_node_tool_version vite 2>/dev/null || echo 'N/A')"
    echo "Vitest:          $(project_node_tool_version vitest 2>/dev/null || echo 'N/A')"
    echo "Biome:           $(project_node_tool_version biome 2>/dev/null || echo 'N/A')"
    echo "Turbo:           $(project_node_tool_version turbo 2>/dev/null || echo 'N/A')"
    echo "pytest:          $(project_python_tool_version pytest 2>/dev/null || echo 'N/A')"
    echo "Ollama:          $(ollama_installed_version 2>/dev/null || echo 'N/A')"
    echo "Claude Code:     $(claude --version 2>/dev/null || echo 'N/A')"
    echo "OpenAI Codex:    $(codex --version 2>/dev/null || echo 'N/A')"
    if [ -n "$copilot_version_value" ]; then
        echo "GitHub Copilot:  $copilot_version_value"
    else
        echo "GitHub Copilot:  N/A"
    fi
}

update_tool() {
    local tool="$1"
    case "$tool" in
        azure-cli)    update_azure_cli ;;
        github-cli)   update_github_cli ;;
        git)          update_git ;;
        docker)       update_docker ;;
        node)         update_node ;;
        npm)          update_npm ;;
        python)       update_python ;;
        uv)           update_uv ;;
        node-deps|npm-tools|npm-dev-tools) sync_node_dependencies ;;
        node-deps-check|check-node-deps) check_node_dependencies ;;
        python-deps|pytest) sync_python_dependencies ;;
        python-deps-check|check-python-deps) check_python_dependencies ;;
        ollama)       update_ollama ;;
        claude-code)  update_claude_code ;;
        codex)        update_codex ;;
        copilot)      update_copilot ;;
        *)
            echo -e "${RED}Unknown tool: ${tool}${NC}"
            echo "  Run --list to see the supported tool names"
            return 1
            ;;
    esac
}

update_all() {
    echo -e "${CYAN}=== Starting Full Tool Update ===${NC}"
    echo ""
    local failed=()
    for tool in "${DEFAULT_TOOL_NAMES[@]}"; do
        echo "──────────────────────────────────────"
        if ! update_tool "$tool"; then
            failed+=("$tool")
        fi
        echo ""
    done

    if [ ${#failed[@]} -gt 0 ]; then
        echo -e "${RED}=== The Following Tools Failed To Update ===${NC}"
        for t in "${failed[@]}"; do
            echo -e "  ${RED}✗ $t${NC}"
        done
    fi

    echo -e "${YELLOW}Project dependency refreshes are not included in --all.${NC}"
    echo -e "${YELLOW}Run update-tools.sh node-deps and/or update-tools.sh python-deps explicitly when you want to update workspace dependencies.${NC}"

    show_versions
    echo ""
    echo -e "${GREEN}=== Update Complete ===${NC}"
}

main() {
    if [ $# -eq 0 ] || [ "$1" = "--all" ]; then
        update_all
    elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        show_list
    elif [ "$1" = "--versions" ] || [ "$1" = "-v" ]; then
        show_versions
    else
        echo -e "${CYAN}=== Updating Selected Tools ===${NC}"
        echo ""
        for tool in "$@"; do
            echo "──────────────────────────────────────"
            update_tool "$tool"
            echo ""
        done
        echo -e "${GREEN}=== Update Complete ===${NC}"
    fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

if [ "${UPDATE_TOOLS_SKIP_MAIN:-0}" = "1" ]; then
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 0
    else
        exit 0
    fi
fi

main "$@"
