#!/bin/bash
# SPDX-License-Identifier: MIT
# version.sh — Version comparison library
# ============================================================================
# Provides version string normalization and comparison functions
# ============================================================================

# Extracts the numeric portion of a version string
# Usage: normalize_version "ollama version is 0.5.6"  # => "0.5.6"
normalize_version() {
    printf '%s\n' "$1" | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1 || true
}

# Checks for exact version match
# Usage: versions_match "1.2.3" "1.2.3"  # => true
versions_match() {
    local current_version="${1:-}"
    local desired_version="${2:-}"

    current_version="$(normalize_version "$current_version")"
    desired_version="$(normalize_version "$desired_version")"

    [ -n "$current_version" ] && [ -n "$desired_version" ] && [ "$current_version" = "$desired_version" ]
}

# Determines whether to skip update when versions match
# Usage: skip_if_same_version "1.2.3" "1.2.3"  # => true (skip)
skip_if_same_version() {
    local current_output="$1"
    local desired_version="$2"

    if versions_match "$current_output" "$desired_version"; then
        if command -v print_already_current >/dev/null 2>&1; then
            print_already_current "$current_output"
        fi
        return 0
    fi

    return 1
}
