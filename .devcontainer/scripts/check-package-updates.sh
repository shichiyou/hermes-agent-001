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
Usage: check-package-updates.sh

Checks whether npm dependencies need attention in three buckets:
  1. package.json range updates
  2. lockfile / node_modules sync only
  3. npm audit security findings

Exit codes:
  0  No action needed
  1  At least one dependency or security check needs attention
  2  Usage error or runtime failure
EOF
}

package_json_has_workspaces() {
  local package_json_path="$1/package.json"

  [ -f "$package_json_path" ] || return 1

  node -e "const packageJson = require(process.argv[1]); const workspaces = packageJson.workspaces; process.exit(Array.isArray(workspaces) || Array.isArray(workspaces?.packages) ? 0 : 1)" "$package_json_path"
}

find_package_update_root() {
  local dir="$PWD"
  local fallback_dir=""
  local preferred_dir=""

  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ]; then
      if [ -z "$fallback_dir" ]; then
        fallback_dir="$dir"
      fi

      if [ -f "$dir/package-lock.json" ] || package_json_has_workspaces "$dir"; then
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

package_label() {
    local root_dir="$1"
    local package_dir="$2"

    if [ "$package_dir" = "$root_dir" ]; then
        printf '%s\n' '.'
        return 0
    fi

    printf '%s\n' "${package_dir#"${root_dir}/"}"
}

workspace_manifest_dirs() {
    local root_dir="$1"

    node - "$root_dir" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const rootDir = process.argv[2];

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function normalizeWorkspaces(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (value && Array.isArray(value.packages)) {
    return value.packages;
  }

  return [];
}

function escapeRegex(source) {
  return source.replace(/[|\\{}()[\]^$+?.]/g, '\\$&');
}

function globToRegex(pattern) {
  let regex = '';

  for (let index = 0; index < pattern.length; index += 1) {
    const character = pattern[index];

    if (character === '*') {
      const nextCharacter = pattern[index + 1];
      const nextNextCharacter = pattern[index + 2];

      if (nextCharacter === '*' && nextNextCharacter === '/') {
        regex += '(?:.*/)?';
        index += 2;
        continue;
      }

      if (nextCharacter === '*') {
        regex += '.*';
        index += 1;
        continue;
      }

      regex += '[^/]*';
      continue;
    }

    if (character === '?') {
      regex += '[^/]';
      continue;
    }

    if (character === '/') {
      regex += '/';
      continue;
    }

    regex += escapeRegex(character);
  }

  return new RegExp(`^${regex}$`);
}

function shouldSkipDirectory(directoryName) {
  return directoryName === '.git'
    || directoryName === '.venv'
    || directoryName === '.worktree'
    || directoryName === 'node_modules';
}

const rootPackageJsonPath = path.join(rootDir, 'package.json');
if (!fs.existsSync(rootPackageJsonPath)) {
  process.exit(0);
}

const rootPackageJson = readJson(rootPackageJsonPath) || {};
const workspaceMatchers = normalizeWorkspaces(rootPackageJson.workspaces).map(globToRegex);
const seen = new Set([rootDir]);
const results = [rootDir];

function walk(currentDirectory, relativeDirectory = '') {
  for (const entry of fs.readdirSync(currentDirectory, { withFileTypes: true })) {
    if (!entry.isDirectory()) {
      continue;
    }

    if (shouldSkipDirectory(entry.name)) {
      continue;
    }

    const nextDirectory = path.join(currentDirectory, entry.name);
    const nextRelativeDirectory = relativeDirectory ? `${relativeDirectory}/${entry.name}` : entry.name;
    const packageJsonPath = path.join(nextDirectory, 'package.json');

    if (fs.existsSync(packageJsonPath) && workspaceMatchers.some((matcher) => matcher.test(nextRelativeDirectory)) && !seen.has(nextDirectory)) {
      seen.add(nextDirectory);
      results.push(nextDirectory);
    }

    walk(nextDirectory, nextRelativeDirectory);
  }
}

walk(rootDir);

results.sort((left, right) => {
  if (left === rootDir) {
    return -1;
  }

  if (right === rootDir) {
    return 1;
  }

  return left.localeCompare(right);
});

process.stdout.write(results.join('\n'));
NODE
}

run_npm_json() {
    local root_dir="$1"
    shift

    local stderr_file
    local stdout
    local stderr
    local status

    stderr_file="$(mktemp)"

    set +e
    stdout="$(cd "$root_dir" && npm "$@" 2>"$stderr_file")"
    status=$?
    set -e

    stderr="$(<"$stderr_file")"
    rm -f "$stderr_file"

    if [ "$status" -ne 0 ] && [ "$status" -ne 1 ]; then
        if [ -n "$stderr" ]; then
            printf '%s\n' "$stderr" >&2
        fi

        if [ -n "$stdout" ]; then
            printf '%s\n' "$stdout" >&2
        fi

        return "$status"
    fi

    printf '%s' "$stdout"
}

classify_outdated_json() {
    local label="$1"
    local outdated_json="$2"

  CHECK_PACKAGE_LABEL="$label" CHECK_NPM_OUTDATED_JSON="$outdated_json" node <<'NODE'
const label = process.env.CHECK_PACKAGE_LABEL || ".";
const input = (process.env.CHECK_NPM_OUTDATED_JSON || "").trim();

if (!input) {
  process.exit(0);
}

let payload;

try {
  payload = JSON.parse(input);
} catch (error) {
  console.error(`Invalid npm outdated JSON for ${label}: ${error.message}`);
  process.exit(2);
}

for (const [packageName, versionInfo] of Object.entries(payload)) {
  const current = String(versionInfo.current ?? '');
  const wanted = String(versionInfo.wanted ?? '');
  const latest = String(versionInfo.latest ?? '');
  const bucket = wanted !== latest ? 'range' : 'sync';

  process.stdout.write([bucket, label, packageName, current, wanted, latest].join('\t'));
  process.stdout.write('\n');
}
NODE
}

summarize_audit_json() {
    local audit_json="$1"

    CHECK_NPM_AUDIT_JSON="$audit_json" node <<'NODE'
const counts = {
  info: 0,
  low: 0,
  moderate: 0,
  high: 0,
  critical: 0,
};

const input = (process.env.CHECK_NPM_AUDIT_JSON || "").trim();
if (!input) {
  process.stdout.write('0\t0\t0\t0\t0\t0');
  process.exit(0);
}

let payload;

try {
  payload = JSON.parse(input);
} catch (error) {
  console.error(`Invalid npm audit JSON: ${error.message}`);
  process.exit(2);
}

if (payload && typeof payload === 'object' && payload.error) {
  console.error(payload.error.summary || payload.error.message || 'npm audit failed');
  process.exit(2);
}

if (payload?.metadata?.vulnerabilities) {
  for (const level of Object.keys(counts)) {
    counts[level] = Number(payload.metadata.vulnerabilities[level] || 0);
  }
} else if (payload?.advisories && typeof payload.advisories === 'object') {
  for (const advisory of Object.values(payload.advisories)) {
    if (advisory && typeof advisory === 'object' && typeof advisory.severity === 'string' && advisory.severity in counts) {
      counts[advisory.severity] += 1;
    }
  }
} else if (payload?.vulnerabilities && typeof payload.vulnerabilities === 'object') {
  for (const vulnerability of Object.values(payload.vulnerabilities)) {
    if (vulnerability && typeof vulnerability === 'object' && typeof vulnerability.severity === 'string' && vulnerability.severity in counts) {
      counts[vulnerability.severity] += 1;
    }
  }
}

const total = Number(
  payload?.metadata?.vulnerabilities?.total
  ?? Object.values(counts).reduce((sum, count) => sum + count, 0),
);

process.stdout.write([
  total,
  counts.info,
  counts.low,
  counts.moderate,
  counts.high,
  counts.critical,
].join('\t'));
NODE
}

print_update_section() {
    local title="$1"
    shift

    echo "$title"

    if [ $# -eq 0 ]; then
        echo "  None"
        return 0
    fi

    local entry
    local label
    local package_name
    local current
    local wanted
    local latest
    for entry in "$@"; do
        IFS='|' read -r label package_name current wanted latest <<<"$entry"
        echo "  - ${label}: ${package_name} (current: ${current}, wanted: ${wanted}, latest: ${latest})"
    done
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

    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}node is required to inspect package manifests.${NC}" >&2
        return 2
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}npm is required to inspect dependency updates.${NC}" >&2
        return 2
    fi

    local root_dir
    if ! root_dir="$(find_package_update_root)"; then
        echo -e "${YELLOW}No project workspace found from current directory.${NC}" >&2
        echo -e "${YELLOW}Run this command from the repository root or one of its subdirectories.${NC}" >&2
        return 2
    fi

    if [ ! -f "$root_dir/package.json" ]; then
        echo -e "${RED}package.json not found at workspace root: ${root_dir}${NC}" >&2
        return 2
    fi

    local -a manifest_dirs=()
    mapfile -t manifest_dirs < <(workspace_manifest_dirs "$root_dir")

    if [ ${#manifest_dirs[@]} -eq 0 ]; then
        manifest_dirs=("$root_dir")
    fi

    local -a range_updates=()
    local -a sync_updates=()
    local package_dir
    local label
    local outdated_json
    local parsed_updates
    local bucket
    local package_name
    local current
    local wanted
    local latest

    for package_dir in "${manifest_dirs[@]}"; do
        label="$(package_label "$root_dir" "$package_dir")"

        if [ "$package_dir" = "$root_dir" ]; then
            outdated_json="$(run_npm_json "$root_dir" outdated --json --workspaces=false)" || {
                echo -e "${RED}Failed to query npm outdated for ${label}.${NC}" >&2
                return 2
            }
        else
            outdated_json="$(run_npm_json "$root_dir" outdated --json --workspace "$label")" || {
                echo -e "${RED}Failed to query npm outdated for ${label}.${NC}" >&2
                return 2
            }
        fi

        parsed_updates="$(classify_outdated_json "$label" "$outdated_json")" || {
            echo -e "${RED}Failed to parse npm outdated output for ${label}.${NC}" >&2
            return 2
        }

        while IFS=$'\t' read -r bucket label package_name current wanted latest; do
            [ -n "$bucket" ] || continue

            if [ "$bucket" = "range" ]; then
                range_updates+=("${label}|${package_name}|${current}|${wanted}|${latest}")
            else
                sync_updates+=("${label}|${package_name}|${current}|${wanted}|${latest}")
            fi
        done <<<"$parsed_updates"
    done

    local audit_json
    local audit_summary
    local audit_total
    local audit_info
    local audit_low
    local audit_moderate
    local audit_high
    local audit_critical

    audit_json="$(run_npm_json "$root_dir" audit --json)" || {
        echo -e "${RED}Failed to query npm audit.${NC}" >&2
        return 2
    }

    audit_summary="$(summarize_audit_json "$audit_json")" || {
        echo -e "${RED}Failed to parse npm audit output.${NC}" >&2
        return 2
    }

    IFS=$'\t' read -r audit_total audit_info audit_low audit_moderate audit_high audit_critical <<<"$audit_summary"

    echo -e "${CYAN}=== Node Package Update Check ===${NC}"
    echo "Workspace root: $root_dir"
    echo "Checked manifests:"
    for package_dir in "${manifest_dirs[@]}"; do
        echo "  - $(package_label "$root_dir" "$package_dir")"
    done
    echo ""

    print_update_section "Package.json range updates needed:" "${range_updates[@]}"
    echo ""
    print_update_section "Lockfile / node_modules sync needed:" "${sync_updates[@]}"
    echo ""
    echo "Security findings:"
    if [ "${audit_total:-0}" -eq 0 ]; then
        echo "  None"
    else
        echo "  - total: ${audit_total} (info: ${audit_info}, low: ${audit_low}, moderate: ${audit_moderate}, high: ${audit_high}, critical: ${audit_critical})"
    fi
    echo ""

    local range_count="${#range_updates[@]}"
    local sync_count="${#sync_updates[@]}"
    local exit_code=0

    if [ "$range_count" -gt 0 ] || [ "$sync_count" -gt 0 ] || [ "${audit_total:-0}" -gt 0 ]; then
        exit_code=1
        echo -e "${YELLOW}Summary: ${range_count} range update(s), ${sync_count} sync-only update(s), ${audit_total} security finding(s).${NC}"
    else
        echo -e "${GREEN}Summary: no package updates or security findings detected.${NC}"
    fi

    return "$exit_code"
}

main "$@"
