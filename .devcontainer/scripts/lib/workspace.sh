#!/bin/bash
# SPDX-License-Identifier: MIT
# workspace.sh — Workspace detection library
# ============================================================================
# Provides project workspace detection and validation functions
# ============================================================================

# Detects the workspace root directory
# Returns the nearest parent directory containing package.json or pyproject.toml
# Usage: find_workspace_root  # => "/path/to/workspace"
find_workspace_root() {
    local dir

    if [ "$#" -gt 0 ]; then
        dir="$1"
    else
        dir="$PWD"
    fi

    while [ "$dir" != "/" ]; do
        if [ -f "$dir/package.json" ] || [ -f "$dir/pyproject.toml" ]; then
            printf '%s\n' "$dir"
            return 0
        fi

        dir="$(dirname "$dir")"
    done

    return 1
}

# Validates that workspace root exists, aborts if not found
# Usage: require_workspace_root  # => prints error and returns 1 if missing
require_workspace_root() {
    if ! find_workspace_root "$PWD" >/dev/null 2>&1; then
        echo "No project workspace found from current directory." >&2
        echo "Run this command from the repository root or one of its subdirectories." >&2
        return 1
    fi
}

# Gets npm version (packageManager) from package.json
# Usage: workspace_npm_version "/path/to/workspace"  # => "11.12.1"
workspace_npm_version() {
    local workspace_dir="${1:-}"
    if [ -z "$workspace_dir" ]; then
        workspace_dir="$(find_workspace_root "$PWD")" || true
    fi
    [ -z "$workspace_dir" ] && return 1

    node -p "const packageManager = require(process.argv[1]).packageManager || ''; packageManager.startsWith('npm@') ? packageManager.slice(4) : ''" "$workspace_dir/package.json" 2>/dev/null || true
}

# Gets the path to a Node.js tool installed in the workspace
# Usage: workspace_node_tool_path "/path/to/workspace" "tsc"
workspace_node_tool_path() {
    local workspace_dir="${1:-}"
    local tool_name="$2"

    [ -z "$workspace_dir" ] && return 1

    if [ -x "$workspace_dir/node_modules/.bin/$tool_name" ]; then
        printf '%s\n' "$workspace_dir/node_modules/.bin/$tool_name"
        return 0
    fi

    return 1
}

# Gets the version of a Node.js tool in the workspace
# Usage: workspace_node_tool_version "/path/to/workspace" "tsc"
workspace_node_tool_version() {
    local workspace_dir="${1:-}"
    local tool_name="$2"
    local tool_path

    [ -z "$workspace_dir" ] && return 1

    tool_path="$(workspace_node_tool_path "$workspace_dir" "$tool_name")" || return 1
    "$tool_path" --version 2>/dev/null | head -1
}

# Gets the version of a Python tool in the workspace
# Usage: workspace_python_tool_version "/path/to/workspace" "pytest"
workspace_python_tool_version() {
    local workspace_dir="${1:-}"
    local tool_name="$2"

    [ -z "$workspace_dir" ] && return 1

    if [ -x "$workspace_dir/.venv/bin/$tool_name" ]; then
        "$workspace_dir/.venv/bin/$tool_name" --version 2>/dev/null | head -1
        return 0
    fi

    return 1
}
