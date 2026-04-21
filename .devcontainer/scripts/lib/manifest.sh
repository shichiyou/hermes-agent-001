#!/bin/bash
# SPDX-License-Identifier: MIT
# manifest.sh — Manifest refresh library
# ============================================================================
# Provides helpers for refreshing workspace dependency pins and devcontainer
# runtime feature pins to the latest available versions.
# ============================================================================

node_latest_lts_version() {
    curl -fsSL https://nodejs.org/dist/index.json | node -e "
const fs = require('node:fs');

function compareVersions(left, right) {
  const leftParts = left.replace(/^v/, '').split('.').map((value) => Number(value));
  const rightParts = right.replace(/^v/, '').split('.').map((value) => Number(value));

  for (let index = 0; index < Math.max(leftParts.length, rightParts.length); index += 1) {
    const difference = (leftParts[index] || 0) - (rightParts[index] || 0);
    if (difference !== 0) {
      return difference;
    }
  }

  return 0;
}

const payload = fs.readFileSync(0, 'utf8');
const releases = JSON.parse(payload).filter((entry) => entry.lts);
releases.sort((left, right) => compareVersions(left.version, right.version));

const latest = releases.at(-1);
if (latest) {
  process.stdout.write(latest.version.replace(/^v/, ''));
}
"
}

node_feature_latest_version() {
    local latest_version
    latest_version="$(node_latest_lts_version || true)"
    [ -n "$latest_version" ] || return 1

    printf '%s\n' "${latest_version%%.*}"
}

python_feature_latest_version() {
    local installed_version
    local latest_version

    # Prefer the currently installed interpreter because the devcontainers
    # Python feature can lag the newest upstream minor release.
    installed_version="$(python3 --version 2>/dev/null | grep -Eo '3\.[0-9]+\.[0-9]+' | head -1 || true)"
    if [ -n "$installed_version" ]; then
        awk -F. '{ printf "%s.%s\n", $1, $2 }' <<<"$installed_version"
        return 0
    fi

    latest_version="$(curl -fsSL https://www.python.org/ftp/python/ | grep -Eo '3\.[0-9]+\.[0-9]+/' | tr -d '/' | sort -V | tail -1)"
    [ -n "$latest_version" ] || return 1

    awk -F. '{ printf "%s.%s\n", $1, $2 }' <<<"$latest_version"
}

manifest_npm_package_latest_version() {
    npm view "$1" version 2>/dev/null | head -1
}

refresh_package_manager_pin() {
    local root_dir="$1"
    local package_json_path="$root_dir/package.json"
    local desired_version

    [ -f "$package_json_path" ] || return 0

    desired_version="$(manifest_npm_package_latest_version npm || true)"
    [ -n "$desired_version" ] || return 1

    PACKAGE_JSON_PATH="$package_json_path" DESIRED_NPM_VERSION="$desired_version" node - <<'NODE'
const fs = require('node:fs');

const packageJsonPath = process.env.PACKAGE_JSON_PATH;
const desiredVersion = process.env.DESIRED_NPM_VERSION;

const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const nextPackageManager = `npm@${desiredVersion}`;

if (packageJson.packageManager !== nextPackageManager) {
  packageJson.packageManager = nextPackageManager;
  fs.writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);
}
NODE
}

package_json_dependency_records() {
    local root_dir="$1"
    local package_json_path="$root_dir/package.json"

    [ -f "$package_json_path" ] || return 0

    node - "$package_json_path" <<'NODE'
const fs = require('node:fs');

const packageJsonPath = process.argv[2];
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const sections = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
];

for (const section of sections) {
  const dependencies = packageJson[section] || {};
  for (const [name, specifier] of Object.entries(dependencies)) {
    process.stdout.write(`${section}\t${name}\t${specifier}\n`);
  }
}
NODE
}

npm_save_flag_for_section() {
    case "$1" in
        dependencies) printf '%s\n' '--save-prod' ;;
        devDependencies) printf '%s\n' '--save-dev' ;;
        optionalDependencies) printf '%s\n' '--save-optional' ;;
        peerDependencies) printf '%s\n' '--save-peer' ;;
        *) return 1 ;;
    esac
}

npm_save_mode_for_specifier() {
    local specifier="$1"

    case "$specifier" in
        workspace:*|file:*|link:*|git:*|git+*|http:*|https:*|github:*|npm:*|catalog:*|'*')
            printf '%s\n' 'skip'
            ;;
        ^*)
            printf '%s\n' 'prefix:^'
            ;;
        ~*)
            printf '%s\n' 'prefix:~'
            ;;
        [0-9]*|[vV][0-9]*)
            printf '%s\n' 'exact'
            ;;
        *)
            printf '%s\n' 'prefix:^'
            ;;
    esac
}

first_numeric_version() {
    printf '%s\n' "$1" | grep -Eo '[0-9]+(\.[0-9]+)*' | head -1 || true
}

version_major() {
    local version="$1"

    [ -n "$version" ] || return 1
    printf '%s\n' "${version%%.*}"
}

npm_package_latest_same_major_version() {
    local package_name="$1"
    local specifier="$2"
    local anchor_version
    local current_major
    local next_major
    local range
    local latest_version

    anchor_version="$(first_numeric_version "$specifier")"
    [ -n "$anchor_version" ] || return 1

    current_major="$(version_major "$anchor_version")" || return 1
    next_major="$((current_major + 1))"
    range=">=${current_major}.0.0 <${next_major}.0.0"
    latest_version="$(npm view "${package_name}@${range}" version 2>/dev/null | awk '{print $NF}' | tr -d "'" | tail -1 || true)"
    [ -n "$latest_version" ] || return 1

    printf '%s\n' "$latest_version"
}

run_npm_dependency_batch() {
    local root_dir="$1"
    local save_flag="$2"
    local save_mode="$3"

    shift 3
    [ $# -gt 0 ] || return 0

    case "$save_mode" in
        exact)
            (cd "$root_dir" && npm_config_save_exact=true npm install "$@" "$save_flag" --package-lock-only --ignore-scripts)
            ;;
        prefix:*)
            local save_prefix
            save_prefix="${save_mode#prefix:}"
            (cd "$root_dir" && npm_config_save_prefix="$save_prefix" npm install "$@" "$save_flag" --package-lock-only --ignore-scripts)
            ;;
        *)
            return 1
            ;;
    esac
}

refresh_package_json_dependency_pins() {
    local root_dir="$1"
    local records_file
    local grouped_file
    local status=0
    local current_key=''
    local current_save_flag=''
    local current_save_mode=''
    local -a current_packages=()

    [ -f "$root_dir/package.json" ] || return 0

    records_file="$(mktemp)"
    grouped_file="$(mktemp)"
    package_json_dependency_records "$root_dir" >"$records_file"

    while IFS=$'\t' read -r section package_name specifier; do
        local desired_version
        local package_spec
        local save_flag
        local save_mode

        [ -n "$package_name" ] || continue

        save_flag="$(npm_save_flag_for_section "$section")" || {
            status=1
            continue
        }
        save_mode="$(npm_save_mode_for_specifier "$specifier")"

        case "$save_mode" in
            skip)
                continue
                ;;
            exact)
                desired_version="$(npm_package_latest_same_major_version "$package_name" "$specifier" || true)"
                if [ -z "$desired_version" ]; then
                    status=1
                    continue
                fi
                package_spec="${package_name}@${desired_version}"
                printf '%s\t%s\t%s\t%s\n' "$section" "$save_mode" "$save_flag" "$package_spec" >>"$grouped_file"
                ;;
            prefix:*)
                desired_version="$(npm_package_latest_same_major_version "$package_name" "$specifier" || true)"
                if [ -z "$desired_version" ]; then
                    status=1
                    continue
                fi
                package_spec="${package_name}@${desired_version}"
                printf '%s\t%s\t%s\t%s\n' "$section" "$save_mode" "$save_flag" "$package_spec" >>"$grouped_file"
                ;;
            *)
                status=1
                ;;
        esac
    done <"$records_file"

    if [ -s "$grouped_file" ]; then
        while IFS=$'\t' read -r section save_mode save_flag package_spec; do
            local batch_key

            batch_key="${section}"$'\t'"${save_mode}"$'\t'"${save_flag}"

            if [ -n "$current_key" ] && [ "$batch_key" != "$current_key" ]; then
                if ! run_npm_dependency_batch "$root_dir" "$current_save_flag" "$current_save_mode" "${current_packages[@]}"; then
                    status=1
                fi
                current_packages=()
            fi

            current_key="$batch_key"
            current_save_flag="$save_flag"
            current_save_mode="$save_mode"
            current_packages+=("$package_spec")
        done < <(sort -s -t $'\t' -k1,1 -k2,2 -k3,3 "$grouped_file")

        if [ ${#current_packages[@]} -gt 0 ]; then
            if ! run_npm_dependency_batch "$root_dir" "$current_save_flag" "$current_save_mode" "${current_packages[@]}"; then
                status=1
            fi
        fi
    fi

    rm -f "$records_file" "$grouped_file"
    return "$status"
}

python_package_latest_same_major_version() {
    local package_name="$1"
    local anchor_version="$2"
    local current_major

    current_major="$(version_major "$anchor_version")" || return 1

    curl -fsSL "https://pypi.org/pypi/${package_name}/json" | python3 -c '
from __future__ import annotations

import json
import re
import sys

major = int(sys.argv[1])
payload = json.load(sys.stdin)
version_pattern = re.compile(r"^\d+(?:\.\d+)*$")
versions: list[tuple[tuple[int, ...], str]] = []

for version_text, files in payload.get("releases", {}).items():
    if not files:
        continue
    if not version_pattern.fullmatch(version_text):
        continue

    parts = tuple(int(value) for value in version_text.split("."))
    if not parts or parts[0] != major:
        continue

    versions.append((parts, version_text))

versions.sort()
if versions:
    print(versions[-1][1])
' "$current_major"
}

python_requirement_upper_bound() {
    local specifier="$1"
    local anchor_version="$2"
    local current_major
    local next_major
    local best_operator=''
    local best_version=''

    current_major="$(version_major "$anchor_version")" || return 1
    next_major="$((current_major + 1))"

    while IFS=$'\t' read -r operator version; do
        [ -n "$operator" ] || continue

        if [ -z "$best_version" ]; then
            best_operator="$operator"
            best_version="$version"
            continue
        fi

        if [ "$(printf '%s\n%s\n' "$version" "$best_version" | sort -V | head -1)" = "$version" ]; then
            if [ "$version" != "$best_version" ] || [ "$operator" = '<' ]; then
                best_operator="$operator"
                best_version="$version"
            fi
        fi
    done < <(printf '%s\n' "$specifier" | grep -Eo '(<=|<)[[:space:]]*[0-9]+(\.[0-9]+)*' | sed -E 's/^(<=|<)[[:space:]]*/\1\t/' || true)

    if [ -n "$best_version" ] && [ "$(printf '%s\n%s\n' "$best_version" "$next_major" | sort -V | head -1)" = "$best_version" ]; then
        if [ "$best_version" = "$next_major" ] && [ "$best_operator" = '<=' ]; then
            printf '<%s\n' "$next_major"
        else
            printf '%s%s\n' "$best_operator" "$best_version"
        fi
        return 0
    fi

    printf '<%s\n' "$next_major"
}

python_requirement_exclusions() {
    local specifier="$1"

    printf '%s\n' "$specifier" | grep -Eo '!=[[:space:]]*[0-9]+(\.[0-9]+)*' | sed -E 's/[[:space:]]+//g' | paste -sd, - || true
}

python_add_requirement_for_specifier() {
    local name_with_extras="$1"
    local package_name="$2"
    local specifier="$3"
    local marker="$4"
    local anchor_version
    local latest_version
    local upper_bound
    local exclusions

    anchor_version="$(first_numeric_version "$specifier")"
    if [ -z "$anchor_version" ]; then
        printf '%s%s%s\n' "$name_with_extras" "$specifier" "$marker"
        return 0
    fi

    latest_version="$(python_package_latest_same_major_version "$package_name" "$anchor_version" || true)"
    if [ -z "$latest_version" ]; then
        printf '%s%s%s\n' "$name_with_extras" "$specifier" "$marker"
        return 0
    fi

    if printf '%s\n' "$specifier" | grep -Eq '===?[[:space:]]*[0-9]'; then
        printf '%s==%s%s\n' "$name_with_extras" "$latest_version" "$marker"
        return 0
    fi

    if printf '%s\n' "$specifier" | grep -Eq '~=[[:space:]]*[0-9]'; then
        printf '%s~=%s%s\n' "$name_with_extras" "$latest_version" "$marker"
        return 0
    fi

    upper_bound="$(python_requirement_upper_bound "$specifier" "$anchor_version")"
    exclusions="$(python_requirement_exclusions "$specifier")"

    if [ -n "$exclusions" ]; then
        printf '%s>=%s,%s,%s%s\n' "$name_with_extras" "$latest_version" "$upper_bound" "$exclusions" "$marker"
    else
        printf '%s>=%s,%s%s\n' "$name_with_extras" "$latest_version" "$upper_bound" "$marker"
    fi
}

pyproject_dependency_records() {
    local root_dir="$1"
    local root_pyproject_path="$root_dir/pyproject.toml"

    [ -f "$root_pyproject_path" ] || return 0

    # Use ASCII Record Separator (0x1E) as delimiter instead of tab.
    # Tab is IFS whitespace in POSIX, so consecutive tabs (empty group_name)
    # collapse into a single delimiter and cause field misalignment.
    local _RS=$'\x1e'

    python3 - "$root_dir" "$_RS" <<'PY'
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

REQUIREMENT_PATTERN = re.compile(
    r'^\s*(?P<name>[A-Za-z0-9_.-]+(?:\[[^\]]+\])?)(?P<specifier>\s*(?:[<>=!~].*?)?)?(?P<marker>\s*;.*)?\s*$'
)

DELIM = sys.argv[2]


def discover_manifest_paths(root_dir: Path) -> list[Path]:
    manifest_paths = [root_dir / 'pyproject.toml']
    root_data = tomllib.loads((root_dir / 'pyproject.toml').read_text())
    members = root_data.get('tool', {}).get('uv', {}).get('workspace', {}).get('members', [])

    seen = {manifest_paths[0].resolve()}
    for pattern in members:
        for candidate_dir in root_dir.glob(pattern):
            candidate_manifest = candidate_dir / 'pyproject.toml'
            if not candidate_manifest.is_file():
                continue

            resolved_path = candidate_manifest.resolve()
            if resolved_path in seen:
                continue

            seen.add(resolved_path)
            manifest_paths.append(candidate_manifest)

    manifest_paths.sort(key=lambda path: '.' if path.parent == root_dir else path.parent.relative_to(root_dir).as_posix())
    return manifest_paths


def update_record(manifest_path: Path, bucket: str, group_name: str, requirement_text: str) -> None:
    match = REQUIREMENT_PATTERN.match(requirement_text)
    if not match:
        return

    specifier = (match.group('specifier') or '').strip()
    if not specifier:
        return

    name_with_extras = match.group('name')
    package_name = name_with_extras.split('[', 1)[0]
    marker = match.group('marker') or ''
    print(DELIM.join([str(manifest_path), bucket, group_name, package_name, name_with_extras, specifier, marker]))

root_dir = Path(sys.argv[1]).resolve()
for manifest_path in discover_manifest_paths(root_dir):
    data = tomllib.loads(manifest_path.read_text())

    for requirement_text in data.get('project', {}).get('dependencies', []):
        update_record(manifest_path, 'project', '', requirement_text)

    for group_name, requirement_texts in data.get('project', {}).get('optional-dependencies', {}).items():
        for requirement_text in requirement_texts:
            update_record(manifest_path, 'optional', group_name, requirement_text)

    for group_name, requirement_texts in data.get('dependency-groups', {}).items():
        for requirement_text in requirement_texts:
            update_record(manifest_path, 'group', group_name, requirement_text)
PY
}

refresh_pyproject_dependency_pins() {
    local root_dir="$1"
    local records_file
    local grouped_file
    local status=0
    local current_key=''
    local current_manifest_dir=''
    local current_bucket=''
    local current_group_name=''
    local -a current_packages=()
    local -a current_requirements=()

    [ -f "$root_dir/pyproject.toml" ] || return 0

    # Use the same Record Separator throughout the pipeline.
    # See pyproject_dependency_records() for the rationale.
    local _RS=$'\x1e'

    records_file="$(mktemp)"
    grouped_file="$(mktemp)"
    pyproject_dependency_records "$root_dir" >"$records_file"

    while IFS="$_RS" read -r manifest_path bucket group_name package_name name_with_extras specifier marker; do
        local add_requirement

        [ -n "$manifest_path" ] || continue
        add_requirement="$(python_add_requirement_for_specifier "$name_with_extras" "$package_name" "$specifier" "$marker")"
        printf '%s%s%s%s%s%s%s%s%s\n' "$manifest_path" "$_RS" "$bucket" "$_RS" "$group_name" "$_RS" "$package_name" "$_RS" "$add_requirement" >>"$grouped_file"
    done <"$records_file"

    if [ -s "$grouped_file" ]; then
        while IFS="$_RS" read -r manifest_path bucket group_name package_name add_requirement; do
            local manifest_dir
            local batch_key

            manifest_dir="$(dirname "$manifest_path")"
            batch_key="${manifest_path}"$'\x1e'"${bucket}"$'\x1e'"${group_name}"

            if [ -n "$current_key" ] && [ "$batch_key" != "$current_key" ]; then
                case "$current_bucket" in
                    project)
                        if ! (cd "$current_manifest_dir" && uv remove --no-sync "${current_packages[@]}" && uv add --no-sync "${current_requirements[@]}"); then
                            status=1
                        fi
                        ;;
                    optional)
                        if ! (cd "$current_manifest_dir" && uv remove --optional "$current_group_name" --no-sync "${current_packages[@]}" && uv add --optional "$current_group_name" --no-sync "${current_requirements[@]}"); then
                            status=1
                        fi
                        ;;
                    group)
                        if ! (cd "$current_manifest_dir" && uv remove --group "$current_group_name" --no-sync "${current_packages[@]}" && uv add --group "$current_group_name" --no-sync "${current_requirements[@]}"); then
                            status=1
                        fi
                        ;;
                    *)
                        status=1
                        ;;
                esac

                current_packages=()
                current_requirements=()
            fi

            current_key="$batch_key"
            current_manifest_dir="$manifest_dir"
            current_bucket="$bucket"
            current_group_name="$group_name"
            current_packages+=("$package_name")
            current_requirements+=("$add_requirement")
        done < <(sort -s -t $'\t' -k1,1 -k2,2 -k3,3 "$grouped_file")

        if [ ${#current_packages[@]} -gt 0 ]; then
            case "$current_bucket" in
                project)
                    if ! (cd "$current_manifest_dir" && uv remove --no-sync "${current_packages[@]}" && uv add --no-sync "${current_requirements[@]}"); then
                        status=1
                    fi
                    ;;
                optional)
                    if ! (cd "$current_manifest_dir" && uv remove --optional "$current_group_name" --no-sync "${current_packages[@]}" && uv add --optional "$current_group_name" --no-sync "${current_requirements[@]}"); then
                        status=1
                    fi
                    ;;
                group)
                    if ! (cd "$current_manifest_dir" && uv remove --group "$current_group_name" --no-sync "${current_packages[@]}" && uv add --group "$current_group_name" --no-sync "${current_requirements[@]}"); then
                        status=1
                    fi
                    ;;
                *)
                    status=1
                    ;;
            esac
        fi
    fi

    rm -f "$records_file" "$grouped_file"
    return "$status"
}

update_devcontainer_feature_version() {
    local root_dir="$1"
    local feature_name="$2"
    local desired_version="$3"
    local devcontainer_path="$root_dir/.devcontainer/devcontainer.json"
        local update_status

    [ -f "$devcontainer_path" ] || return 0
    [ -n "$desired_version" ] || return 1

        update_status="$(DEVCONTAINER_JSON_PATH="$devcontainer_path" FEATURE_NAME="$feature_name" FEATURE_VERSION="$desired_version" node - <<'NODE'
const fs = require('node:fs');

const devcontainerPath = process.env.DEVCONTAINER_JSON_PATH;
const featureName = process.env.FEATURE_NAME;
const featureVersion = process.env.FEATURE_VERSION;

const devcontainer = JSON.parse(fs.readFileSync(devcontainerPath, 'utf8'));
const features = devcontainer.features || {};
let didUpdate = false;

for (const [featureKey, featureConfig] of Object.entries(features)) {
  if (!featureKey.startsWith(`ghcr.io/devcontainers/features/${featureName}:`)) {
    continue;
  }

    if (featureConfig.version === featureVersion) {
        continue;
    }

  features[featureKey] = {
    ...featureConfig,
    version: featureVersion,
  };

    didUpdate = true;
}

if (didUpdate) {
    fs.writeFileSync(devcontainerPath, `${JSON.stringify(devcontainer, null, 2)}\n`);
}

process.stdout.write(didUpdate ? 'updated' : 'unchanged');
NODE
)" || return 1

        printf '%s\n' "$update_status"
}

refresh_node_runtime_feature_pin() {
    local root_dir="$1"
    local desired_version

    desired_version="$(node_feature_latest_version || true)"
    [ -n "$desired_version" ] || return 1

    update_devcontainer_feature_version "$root_dir" node "$desired_version"
}

refresh_python_runtime_feature_pin() {
    local root_dir="$1"
    local desired_version

    desired_version="$(python_feature_latest_version || true)"
    [ -n "$desired_version" ] || return 1

    update_devcontainer_feature_version "$root_dir" python "$desired_version"
}
