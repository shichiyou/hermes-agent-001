#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${SCRIPT_DIR}/lib"
# shellcheck source=/dev/null
source "${_LIB_DIR}/workspace.sh"

show_help() {
    cat <<'EOF'
Usage: check-python-package-updates.sh

Checks whether Python dependencies need attention in four buckets:
  1. pyproject.toml specifier updates
  2. uv.lock refreshes within current specifiers
  3. environment synchronization drift
  4. uv audit security findings

Exit codes:
  0  No action needed
  1  At least one dependency or security check needs attention
  2  Usage error or runtime failure
EOF
}

find_python_update_root() {
    local dir="$PWD"
    local fallback_dir=""
    local preferred_dir=""

    while [ "$dir" != "/" ]; do
        if [ -f "$dir/pyproject.toml" ]; then
            fallback_dir="$dir"

            if [ -f "$dir/uv.lock" ]; then
                preferred_dir="$dir"
            fi
        fi

        dir="$(dirname "$dir")"
    done

    if [ -n "$preferred_dir" ]; then
        printf '%s\n' "$preferred_dir"
        return 0
    fi

    if [ -n "$fallback_dir" ]; then
        printf '%s\n' "$fallback_dir"
        return 0
    fi

    return 1
}

detect_python_checker_interpreter() {
    local root_dir="$1"

    if [ -n "${PYTHON_DEP_CHECK_PYTHON:-}" ] && [ -x "${PYTHON_DEP_CHECK_PYTHON}" ]; then
        printf '%s\n' "${PYTHON_DEP_CHECK_PYTHON}"
        return 0
    fi

    if [ -x "$root_dir/.venv/bin/python" ]; then
        printf '%s\n' "$root_dir/.venv/bin/python"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1 && python3 -c 'import packaging, tomllib' >/dev/null 2>&1; then
        command -v python3
        return 0
    fi

    return 1
}

run_uv_command() {
    local root_dir="$1"
    shift

    UV_COMMAND_STDOUT_FILE="$(mktemp)"
    UV_COMMAND_STDERR_FILE="$(mktemp)"

    set +e
    (cd "$root_dir" && uv "$@" >"$UV_COMMAND_STDOUT_FILE" 2>"$UV_COMMAND_STDERR_FILE")
    UV_COMMAND_STATUS=$?
    set -e
}

cleanup_uv_command() {
    rm -f "$UV_COMMAND_STDOUT_FILE" "$UV_COMMAND_STDERR_FILE"
}

python_manifest_labels() {
    local root_dir="$1"
    local python_bin="$2"

    "$python_bin" - "$root_dir" <<'PY'
from __future__ import annotations

import sys
import tomllib
from pathlib import Path


def discover_manifest_paths(root_dir: Path) -> list[Path]:
    manifest_paths = [root_dir / "pyproject.toml"]
    root_data = tomllib.loads((root_dir / "pyproject.toml").read_text())
    members = root_data.get("tool", {}).get("uv", {}).get("workspace", {}).get("members", [])

    seen = {manifest_paths[0].resolve()}
    for pattern in members:
        for candidate_dir in root_dir.glob(pattern):
            candidate_manifest = candidate_dir / "pyproject.toml"
            if not candidate_manifest.is_file():
                continue

            resolved_path = candidate_manifest.resolve()
            if resolved_path in seen:
                continue

            seen.add(resolved_path)
            manifest_paths.append(candidate_manifest)

    manifest_paths.sort(key=lambda path: "." if path.parent == root_dir else path.parent.relative_to(root_dir).as_posix())
    return manifest_paths


root_dir = Path(sys.argv[1]).resolve()
for manifest_path in discover_manifest_paths(root_dir):
    if manifest_path.parent == root_dir:
        print(".")
    else:
        print(manifest_path.parent.relative_to(root_dir).as_posix())
PY
}

classify_outdated_direct_dependencies() {
    local root_dir="$1"
    local python_bin="$2"
    local outdated_json="$3"

    PYTHON_DEP_CHECK_OUTDATED_JSON="$outdated_json" "$python_bin" - "$root_dir" <<'PY'
from __future__ import annotations

import json
import os
import sys
import tomllib
from pathlib import Path

from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.version import InvalidVersion, Version


def normalize_name(name: str) -> str:
    return name.replace("_", "-").replace(".", "-").lower()


def discover_manifest_paths(root_dir: Path) -> list[Path]:
    manifest_paths = [root_dir / "pyproject.toml"]
    root_data = tomllib.loads((root_dir / "pyproject.toml").read_text())
    members = root_data.get("tool", {}).get("uv", {}).get("workspace", {}).get("members", [])

    seen = {manifest_paths[0].resolve()}
    for pattern in members:
        for candidate_dir in root_dir.glob(pattern):
            candidate_manifest = candidate_dir / "pyproject.toml"
            if not candidate_manifest.is_file():
                continue

            resolved_path = candidate_manifest.resolve()
            if resolved_path in seen:
                continue

            seen.add(resolved_path)
            manifest_paths.append(candidate_manifest)

    manifest_paths.sort(key=lambda path: "." if path.parent == root_dir else path.parent.relative_to(root_dir).as_posix())
    return manifest_paths


def requirement_records_for_manifest(root_dir: Path, manifest_path: Path) -> list[tuple[str, str, str, str]]:
    data = tomllib.loads(manifest_path.read_text())
    label = "." if manifest_path.parent == root_dir else manifest_path.parent.relative_to(root_dir).as_posix()
    records: list[tuple[str, str, str, str]] = []

    for requirement_text in data.get("project", {}).get("dependencies", []):
        requirement = Requirement(requirement_text)
        records.append((normalize_name(requirement.name), label, "project", str(requirement.specifier)))

    optional_dependencies = data.get("project", {}).get("optional-dependencies", {})
    for group_name, requirement_texts in optional_dependencies.items():
        for requirement_text in requirement_texts:
            requirement = Requirement(requirement_text)
            records.append((normalize_name(requirement.name), label, f"optional:{group_name}", str(requirement.specifier)))

    dependency_groups = data.get("dependency-groups", {})
    for group_name, requirement_texts in dependency_groups.items():
        for requirement_text in requirement_texts:
            requirement = Requirement(requirement_text)
            records.append((normalize_name(requirement.name), label, group_name, str(requirement.specifier)))

    return records


root_dir = Path(sys.argv[1]).resolve()
outdated_json = (os.environ.get("PYTHON_DEP_CHECK_OUTDATED_JSON") or "").strip()
if not outdated_json:
    sys.exit(0)

try:
    outdated_packages = json.loads(outdated_json)
except json.JSONDecodeError as error:
    print(f"Invalid uv pip list JSON: {error}", file=sys.stderr)
    sys.exit(2)

declared_dependencies: dict[str, list[tuple[str, str, str]]] = {}
for manifest_path in discover_manifest_paths(root_dir):
    for dependency_name, label, group_name, specifier in requirement_records_for_manifest(root_dir, manifest_path):
        declared_dependencies.setdefault(dependency_name, []).append((label, group_name, specifier))

for package_record in outdated_packages:
    dependency_name = normalize_name(package_record["name"])
    if dependency_name not in declared_dependencies:
        continue

    current_version = str(package_record.get("version", ""))
    latest_version = str(package_record.get("latest_version", ""))

    try:
        latest_parsed = Version(latest_version)
    except InvalidVersion:
        latest_parsed = None

    for label, group_name, specifier in declared_dependencies[dependency_name]:
        bucket = "lock"
        if specifier and latest_parsed is not None:
            if not SpecifierSet(specifier).contains(latest_parsed, prereleases=True):
                bucket = "spec"

        print("\t".join([bucket, label, group_name, package_record["name"], current_version, latest_version, specifier]))
PY
}

print_dependency_section() {
    local title="$1"
    shift

    echo "$title"

    if [ $# -eq 0 ]; then
        echo "  None"
        return 0
    fi

    local entry
    local label
    local group_name
    local package_name
    local current_version
    local latest_version
    local specifier
    local location
    for entry in "$@"; do
        IFS='|' read -r label group_name package_name current_version latest_version specifier <<<"$entry"
        location="$label"
        if [ -n "$group_name" ] && [ "$group_name" != "project" ]; then
            location="${location}:${group_name}"
        fi
        echo "  - ${location}: ${package_name} (current: ${current_version}, latest: ${latest_version}, specifier: ${specifier:-*})"
    done
}

print_text_section() {
    local title="$1"
    local section_text="$2"

    echo "$title"

    if [ -z "$section_text" ]; then
        echo "  None"
        return 0
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        echo "  - $line"
    done <<<"$section_text"
}

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_help
        return 0
    fi

    if [ $# -ne 0 ]; then
        show_help >&2
        return 2
    fi

    if ! command -v uv >/dev/null 2>&1; then
        echo -e "${RED}uv is required to inspect Python dependency updates.${NC}" >&2
        return 2
    fi

    local root_dir
    if ! root_dir="$(find_python_update_root)"; then
        echo -e "${YELLOW}No Python project workspace found from current directory.${NC}" >&2
        echo -e "${YELLOW}Run this command from the repository root or one of its subdirectories.${NC}" >&2
        return 2
    fi

    if [ ! -f "$root_dir/pyproject.toml" ]; then
        echo -e "${RED}pyproject.toml not found at workspace root: ${root_dir}${NC}" >&2
        return 2
    fi

    local python_bin
    if ! python_bin="$(detect_python_checker_interpreter "$root_dir")"; then
        echo -e "${RED}A Python interpreter with tomllib and packaging is required for dependency classification.${NC}" >&2
        echo -e "${YELLOW}Run uv sync --dev first, or set PYTHON_DEP_CHECK_PYTHON to an appropriate interpreter.${NC}" >&2
        return 2
    fi

    local -a manifest_labels=()
    mapfile -t manifest_labels < <(python_manifest_labels "$root_dir" "$python_bin")

    if [ ${#manifest_labels[@]} -eq 0 ]; then
        manifest_labels=(".")
    fi

    run_uv_command "$root_dir" pip list --outdated --format json
    if [ "$UV_COMMAND_STATUS" -gt 1 ]; then
        cat "$UV_COMMAND_STDERR_FILE" >&2
        cleanup_uv_command
        echo -e "${RED}Failed to query uv pip list for outdated packages.${NC}" >&2
        return 2
    fi

    local outdated_json
    outdated_json="$(<"$UV_COMMAND_STDOUT_FILE")"
    cleanup_uv_command

    local parsed_outdated
    if ! parsed_outdated="$(classify_outdated_direct_dependencies "$root_dir" "$python_bin" "$outdated_json")"; then
        echo -e "${RED}Failed to classify outdated Python dependencies.${NC}" >&2
        return 2
    fi

    local -a spec_updates=()
    local -a lock_updates=()
    local bucket
    local label
    local group_name
    local package_name
    local current_version
    local latest_version
    local specifier
    while IFS=$'\t' read -r bucket label group_name package_name current_version latest_version specifier; do
        [ -n "$bucket" ] || continue

        if [ "$bucket" = "spec" ]; then
            spec_updates+=("${label}|${group_name}|${package_name}|${current_version}|${latest_version}|${specifier}")
        else
            lock_updates+=("${label}|${group_name}|${package_name}|${current_version}|${latest_version}|${specifier}")
        fi
    done <<<"$parsed_outdated"

    run_uv_command "$root_dir" lock --check
    if [ "$UV_COMMAND_STATUS" -gt 1 ]; then
        cat "$UV_COMMAND_STDERR_FILE" >&2
        cleanup_uv_command
        echo -e "${RED}Failed to check uv.lock status.${NC}" >&2
        return 2
    fi
    local lockfile_status_text=""
    if [ "$UV_COMMAND_STATUS" -eq 1 ]; then
        lockfile_status_text="uv.lock is not up to date with pyproject.toml. Run uv lock."
    fi
    cleanup_uv_command

    run_uv_command "$root_dir" sync --check --all-groups --locked
    if [ "$UV_COMMAND_STATUS" -gt 1 ]; then
        cat "$UV_COMMAND_STDERR_FILE" >&2
        cleanup_uv_command
        echo -e "${RED}Failed to check Python environment synchronization.${NC}" >&2
        return 2
    fi
    local sync_status_text=""
    if [ "$UV_COMMAND_STATUS" -eq 1 ]; then
        sync_status_text="Project environment is not synchronized with uv.lock. Run uv sync --dev."
    fi
    cleanup_uv_command

    run_uv_command "$root_dir" --preview-features audit audit
    if [ "$UV_COMMAND_STATUS" -gt 1 ]; then
        cat "$UV_COMMAND_STDERR_FILE" >&2
        cleanup_uv_command
        echo -e "${RED}Failed to run uv audit.${NC}" >&2
        return 2
    fi
    local audit_status_text=""
    if [ "$UV_COMMAND_STATUS" -eq 1 ]; then
        audit_status_text="$(cat "$UV_COMMAND_STDOUT_FILE")"
        if [ -s "$UV_COMMAND_STDERR_FILE" ]; then
            if [ -n "$audit_status_text" ]; then
                audit_status_text+=$'\n'
            fi
            audit_status_text+="$(cat "$UV_COMMAND_STDERR_FILE")"
        fi
    fi
    cleanup_uv_command

    echo -e "${CYAN}=== Python Package Update Check ===${NC}"
    echo "Workspace root: $root_dir"
    echo "Checked manifests:"
    local manifest_label
    for manifest_label in "${manifest_labels[@]}"; do
        echo "  - $manifest_label"
    done
    echo ""

    print_dependency_section "Pyproject spec updates needed:" "${spec_updates[@]}"
    echo ""
    print_dependency_section "uv.lock refreshes available within current specifiers:" "${lock_updates[@]}"
    echo ""
    print_text_section "uv.lock status:" "$lockfile_status_text"
    echo ""
    print_text_section "Environment sync needed:" "$sync_status_text"
    echo ""
    print_text_section "Security findings:" "$audit_status_text"
    echo ""

    local exit_code=0
    local audit_issue_count=0
    if [ -n "$audit_status_text" ]; then
        audit_issue_count=1
    fi

    if [ ${#spec_updates[@]} -gt 0 ] || [ ${#lock_updates[@]} -gt 0 ] || [ -n "$lockfile_status_text" ] || [ -n "$sync_status_text" ] || [ "$audit_issue_count" -gt 0 ]; then
        exit_code=1
        echo -e "${YELLOW}Summary: ${#spec_updates[@]} spec update(s), ${#lock_updates[@]} lock refresh candidate(s), $([ -n "$lockfile_status_text" ] && printf '1' || printf '0') lockfile drift issue(s), $([ -n "$sync_status_text" ] && printf '1' || printf '0') environment sync issue(s), ${audit_issue_count} security issue set(s).${NC}"
    else
        echo -e "${GREEN}Summary: no Python dependency updates or security findings detected.${NC}"
    fi

    return "$exit_code"
}

main "$@"
