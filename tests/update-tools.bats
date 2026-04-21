#!/usr/bin/env bats

# Load bats-support and bats-assert
load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

# Load the functions under test
load ./functions

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TMPDIR/home"
    export HOME="$TEST_HOME"
    mkdir -p "$TEST_HOME/.local/state"
    mkdir -p "$TEST_HOME/.cache"
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

create_workspace_node_tools() {
    local workspace_dir="$1"

    mkdir -p "$workspace_dir/node_modules/.bin"
    for tool_name in tsc vite vitest biome turbo; do
        cat > "$workspace_dir/node_modules/.bin/$tool_name" <<EOF
#!/bin/bash
echo "$tool_name 1.0.0"
EOF
        chmod +x "$workspace_dir/node_modules/.bin/$tool_name"
    done
}

create_workspace_python_tools() {
    local workspace_dir="$1"

    mkdir -p "$workspace_dir/.venv/bin"
    cat > "$workspace_dir/.venv/bin/pytest" <<'EOF'
#!/bin/bash
echo "pytest 9.0.2"
EOF
    chmod +x "$workspace_dir/.venv/bin/pytest"
}

# --------------------------------------------------------------------------
# normalize_version() tests
# --------------------------------------------------------------------------

@test "normalize_version: extracts version from string" {
    run normalize_version "ollama version is 0.5.6"
    assert_output "0.5.6"
}

@test "normalize_version: extracts first version from string" {
    run normalize_version "docker version 24.0.0 and more 1.2.3"
    assert_output "24.0.0"
}

@test "normalize_version: handles version with v prefix" {
    run normalize_version "v1.2.3"
    assert_output "1.2.3"
}

@test "normalize_version: returns empty for non-version string" {
    run normalize_version "no version here"
    assert_output ""
}

@test "normalize_version: handles version without dot (1.2 style)" {
    run normalize_version "1.2"
    assert_output "1.2"
}

# --------------------------------------------------------------------------
# versions_match() tests
# --------------------------------------------------------------------------

@test "versions_match: returns 0 for matching versions" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '1.2.3' '1.2.3' && echo '0' || echo '1'"
    assert_output "0"
}

@test "versions_match: returns 1 for different versions" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '1.2.3' '1.2.4' && echo '0' || echo '1'"
    assert_output "1"
}

@test "versions_match: returns 1 for empty current" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '' '1.2.3' && echo '0' || echo '1'"
    assert_output "1"
}

@test "versions_match: returns 1 for empty desired" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '1.2.3' '' && echo '0' || echo '1'"
    assert_output "1"
}

# --------------------------------------------------------------------------
# skip_if_same_version() tests
# --------------------------------------------------------------------------

@test "skip_if_same_version: returns 0 when versions match" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && skip_if_same_version '1.2.3' '1.2.3' && echo '0' || echo '1'"
    assert_success
    assert_output --partial "Already up to date (1.2.3)"
    assert_output --partial $'\n0'
}

@test "skip_if_same_version: prints already-up-to-date message when versions match" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && skip_if_same_version 'codex-cli 0.118.0' '0.118.0'"
    assert_success
    assert_output --partial "Already up to date (codex-cli 0.118.0)"
}

@test "skip_if_same_version: returns 1 when versions differ" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && skip_if_same_version '1.2.3' '1.2.4' && echo '0' || echo '1'"
    assert_output "1"
}

# --------------------------------------------------------------------------
# ollama_architecture() tests
# --------------------------------------------------------------------------

@test "ollama_architecture: returns amd64 for x86_64" {
    if [[ "$(uname -m)" != "x86_64" ]]; then
        skip "Not on x86_64"
    fi
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && ollama_architecture"
    assert_output "amd64"
}

@test "ollama_architecture: returns arm64 for aarch64" {
    if [[ "$(uname -m)" != "aarch64" ]]; then
        skip "Not on aarch64"
    fi
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && ollama_architecture"
    assert_output "arm64"
}

@test "ollama_architecture: returns arm64 for arm64" {
    if [[ "$(uname -m)" != "arm64" ]]; then
        skip "Not on arm64"
    fi
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && ollama_architecture"
    assert_output "arm64"
}

# --------------------------------------------------------------------------
# find_workspace_root() tests
# --------------------------------------------------------------------------

@test "find_workspace_root: finds root with package.json" {
    mkdir -p "$TEST_TMPDIR/workspace"
    touch "$TEST_TMPDIR/workspace/package.json"

    run bash -c "cd '$TEST_TMPDIR/workspace' && source '$BATS_TEST_DIRNAME/functions.bash' && find_workspace_root"
    assert_output "$TEST_TMPDIR/workspace"
}

@test "find_workspace_root: finds root from subdirectory" {
    mkdir -p "$TEST_TMPDIR/workspace/subdir/another"
    touch "$TEST_TMPDIR/workspace/package.json"
    cd "$TEST_TMPDIR/workspace/subdir/another"
    run find_workspace_root
    assert_output "$TEST_TMPDIR/workspace"
}

@test "find_workspace_root: returns 1 when no workspace found" {
    cd "$TEST_TMPDIR"
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && find_workspace_root"
    assert_failure
}

# --------------------------------------------------------------------------
# apt_installed_version() tests
# --------------------------------------------------------------------------

@test "apt_installed_version: returns version for installed package" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && apt_installed_version bash"
    if [ -z "$output" ]; then
        skip "bash not tracked by dpkg"
    fi
    assert_output --partial "."
}

@test "apt_installed_version: returns empty for non-installed package" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && apt_installed_version this-package-definitely-does-not-exist-xyz"
    assert_output ""
}

# --------------------------------------------------------------------------
# npm_package_latest_version() tests (network-dependent)
# --------------------------------------------------------------------------

@test "npm_package_latest_version: returns version for npm package" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && npm_package_latest_version bats"
    if [ -z "$output" ] || ! [[ "$output" =~ ^[0-9] ]]; then
        skip "npm registry not accessible"
    fi
    assert_output --partial "."
}

# --------------------------------------------------------------------------
# update_tool() error-path tests
# --------------------------------------------------------------------------

@test "update_tool: returns error for unknown tool" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && update_tool 'unknown-tool-xyz'"
    assert_failure
    assert_output --partial "Unknown tool"
}

@test "update-tools: default update targets exclude project dependency refreshes" {
    run bash -c "UPDATE_TOOLS_SKIP_MAIN=1 source '$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh' && printf '%s\n' \"\${DEFAULT_TOOL_NAMES[@]}\""

    assert_success
    assert_output --partial 'azure-cli'
    refute_output --partial 'node-deps'
    refute_output --partial 'python-deps'
}

@test "update-tools: node-deps refreshes package-lock before npm ci" {
    local workspace_dir="$TEST_TMPDIR/workspace"
    local test_bin="$TEST_TMPDIR/bin"
    local log_file="$TEST_TMPDIR/node-deps.log"
    local real_node

    mkdir -p "$workspace_dir" "$test_bin"
    real_node="$(command -v node)"
    create_workspace_node_tools "$workspace_dir"
    cat > "$workspace_dir/package.json" <<'EOF'
{
  "name": "workspace",
  "devDependencies": {
    "vite": "^1.0.0"
  }
}
EOF
    printf '{"lockfileVersion":3}\n' > "$workspace_dir/package-lock.json"

    cat > "$test_bin/npm" <<EOF
#!/bin/bash
case "\$1" in
    view)
        if [ "\$2" = "vite@>=1.0.0 <2.0.0" ] && [ "\$3" = "version" ]; then
            echo "1.9.9"
            exit 0
        fi
        echo "unexpected npm view invocation: \$*" >&2
        exit 1
        ;;
    install)
        if [ "\$2" = "vite@1.9.9" ]; then
            echo "npm-pin-install" >> "$log_file"
            "$real_node" - "$workspace_dir/package.json" <<'NODE'
const fs = require('node:fs');

const packageJsonPath = process.argv[2];
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
packageJson.devDependencies.vite = '^1.9.9';
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
NODE
            exit 0
        fi
        echo "unexpected npm install invocation: \$*" >&2
        exit 1
        ;;
    update)
        echo "npm-update" >> "$log_file"
        [ "\$2" = "--package-lock-only" ] || exit 1
        ;;
    ci)
        echo "npm-ci" >> "$log_file"
        ;;
    *)
        echo "unexpected npm invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/npm"

    run bash -c "cd '$workspace_dir' && PATH='$test_bin:$PATH' bash '$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh' node-deps"

    assert_success
    assert_equal "$(cat "$log_file")" $'npm-pin-install\nnpm-update\nnpm-ci'
    run grep -F '"vite": "^1.9.9"' "$workspace_dir/package.json"
    assert_success
}

@test "update-tools: node-deps batches matching dependency pin updates" {
    local workspace_dir="$TEST_TMPDIR/workspace"
    local test_bin="$TEST_TMPDIR/bin"
    local log_file="$TEST_TMPDIR/node-deps-batch.log"
    local real_node

    mkdir -p "$workspace_dir" "$test_bin"
    real_node="$(command -v node)"
    create_workspace_node_tools "$workspace_dir"
    cat > "$workspace_dir/package.json" <<'EOF'
{
  "name": "workspace",
  "devDependencies": {
    "vite": "^1.0.0",
    "vitest": "^1.0.0"
  }
}
EOF
    printf '{"lockfileVersion":3}\n' > "$workspace_dir/package-lock.json"

    cat > "$test_bin/npm" <<EOF
#!/bin/bash
case "\$1" in
    view)
        case "\$2" in
            'vite@>=1.0.0 <2.0.0')
                [ "\$3" = "version" ] || exit 1
                echo "1.9.9"
                ;;
            'vitest@>=1.0.0 <2.0.0')
                [ "\$3" = "version" ] || exit 1
                echo "1.8.8"
                ;;
            *)
                echo "unexpected npm view invocation: \$*" >&2
                exit 1
                ;;
        esac
        ;;
    install)
        echo "npm-install:\$*" >> "$log_file"
        if [[ " \$* " != *" vite@1.9.9 "* ]] || [[ " \$* " != *" vitest@1.8.8 "* ]]; then
            echo "expected same-major package versions in one install call" >&2
            exit 1
        fi
        "$real_node" - "$workspace_dir/package.json" <<'NODE'
const fs = require('node:fs');

const packageJsonPath = process.argv[2];
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
packageJson.devDependencies.vite = '^1.9.9';
packageJson.devDependencies.vitest = '^1.8.8';
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
NODE
        ;;
    update)
        echo "npm-update:\$*" >> "$log_file"
        [ "\$2" = "--package-lock-only" ] || exit 1
        ;;
    ci)
        echo "npm-ci:\$*" >> "$log_file"
        ;;
    *)
        echo "unexpected npm invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/npm"

    run bash -c "cd '$workspace_dir' && PATH='$test_bin:$PATH' bash '$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh' node-deps"

    assert_success
    run grep -c '^npm-install:' "$log_file"
    assert_output '1'
    run grep -F 'vite@1.9.9' "$log_file"
    assert_success
    run grep -F 'vitest@1.8.8' "$log_file"
    assert_success
    run grep -F '"vite": "^1.9.9"' "$workspace_dir/package.json"
    assert_success
    run grep -F '"vitest": "^1.8.8"' "$workspace_dir/package.json"
    assert_success
}

@test "update-tools: python-deps refreshes uv.lock before uv sync" {
    local workspace_dir="$TEST_TMPDIR/workspace"
    local test_bin="$TEST_TMPDIR/bin"
    local log_file="$TEST_TMPDIR/python-deps.log"

    mkdir -p "$workspace_dir" "$test_bin"
    create_workspace_python_tools "$workspace_dir"
    cat > "$workspace_dir/pyproject.toml" <<'EOF'
[project]
name = "workspace"
version = "0.0.0"

[dependency-groups]
dev = ["pytest>=7,<8"]
EOF
    printf 'version = 1\n' > "$workspace_dir/uv.lock"

    cat > "$test_bin/curl" <<'EOF'
#!/bin/bash
if [ "$1" = "-fsSL" ] && [ "$2" = "https://pypi.org/pypi/pytest/json" ]; then
    cat <<'JSON'
{"releases":{"7.0.0":[{"filename":"pytest-7.0.0.tar.gz"}],"7.9.9":[{"filename":"pytest-7.9.9.tar.gz"}],"8.0.0":[{"filename":"pytest-8.0.0.tar.gz"}]}}
JSON
    exit 0
fi

echo "unexpected curl invocation: $*" >&2
exit 1
EOF
    chmod +x "$test_bin/curl"

    cat > "$test_bin/uv" <<EOF
#!/bin/bash
case "\$1 \$2" in
    'remove --group')
        echo "uv-remove-dev-pytest" >> "$log_file"
        sed -i 's/dev = \["pytest>=7,<8"\]/dev = []/' "$workspace_dir/pyproject.toml"
        ;;
    'add --group')
        echo "uv-add-dev-pytest" >> "$log_file"
        if [[ " \$* " != *" pytest>=7.9.9,<8 "* ]]; then
            echo "expected same-major pytest requirement" >&2
            exit 1
        fi
        sed -i 's/dev = \[\]/dev = ["pytest>=7.9.9,<8"]/' "$workspace_dir/pyproject.toml"
        ;;
    'lock --upgrade')
        echo "uv-lock-upgrade" >> "$log_file"
        ;;
    'sync --dev')
        echo "uv-sync-dev" >> "$log_file"
        ;;
    *)
        echo "unexpected uv invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/uv"

    run bash -c "cd '$workspace_dir' && PATH='$test_bin:$PATH' bash '$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh' python-deps"

    assert_success
    assert_equal "$(cat "$log_file")" $'uv-remove-dev-pytest\nuv-add-dev-pytest\nuv-lock-upgrade\nuv-sync-dev'
    run grep -F 'dev = ["pytest>=7.9.9,<8"]' "$workspace_dir/pyproject.toml"
    assert_success
}

@test "update-tools: python-deps batches grouped dependency pin updates without syncing" {
    local workspace_dir="$TEST_TMPDIR/workspace"
    local test_bin="$TEST_TMPDIR/bin"
    local log_file="$TEST_TMPDIR/python-deps-batch.log"

    mkdir -p "$workspace_dir" "$test_bin"
    create_workspace_python_tools "$workspace_dir"
    cat > "$workspace_dir/pyproject.toml" <<'EOF'
[project]
name = "workspace"
version = "0.0.0"

[dependency-groups]
dev = ["pytest>=7,<8", "ruff>=0.1,<0.2"]
EOF
    printf 'version = 1\n' > "$workspace_dir/uv.lock"

    cat > "$test_bin/curl" <<'EOF'
#!/bin/bash
case "$2" in
    https://pypi.org/pypi/pytest/json)
        cat <<'JSON'
{"releases":{"7.0.0":[{"filename":"pytest-7.0.0.tar.gz"}],"7.9.9":[{"filename":"pytest-7.9.9.tar.gz"}],"8.0.0":[{"filename":"pytest-8.0.0.tar.gz"}]}}
JSON
        ;;
    https://pypi.org/pypi/ruff/json)
        cat <<'JSON'
{"releases":{"0.1.0":[{"filename":"ruff-0.1.0.tar.gz"}],"0.13.0":[{"filename":"ruff-0.13.0.tar.gz"}],"1.0.0":[{"filename":"ruff-1.0.0.tar.gz"}]}}
JSON
        ;;
    *)
        echo "unexpected curl invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/curl"

    cat > "$test_bin/uv" <<EOF
#!/bin/bash
case "\$1 \$2" in
    'remove --group')
        echo "uv-remove:\$*" >> "$log_file"
        if [[ " \$* " != *" --no-sync "* ]] || [[ " \$* " != *" pytest "* ]] || [[ " \$* " != *" ruff "* ]]; then
            echo "expected batched grouped remove with --no-sync" >&2
            exit 1
        fi
        sed -i 's/dev = \["pytest>=7,<8", "ruff>=0.1,<0.2"\]/dev = []/' "$workspace_dir/pyproject.toml"
        ;;
    'add --group')
        echo "uv-add:\$*" >> "$log_file"
        if [[ " \$* " != *" --no-sync "* ]] || [[ " \$* " != *" pytest>=7.9.9,<8 "* ]] || [[ " \$* " != *" ruff>=0.13.0,<0.2 "* ]]; then
            echo "expected batched grouped add with --no-sync" >&2
            exit 1
        fi
        sed -i 's/dev = \[\]/dev = ["pytest>=7.9.9,<8", "ruff>=0.13.0,<0.2"]/' "$workspace_dir/pyproject.toml"
        ;;
    'lock --upgrade')
        echo "uv-lock-upgrade" >> "$log_file"
        ;;
    'sync --dev')
        echo "uv-sync-dev" >> "$log_file"
        ;;
    *)
        echo "unexpected uv invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/uv"

    run bash -c "cd '$workspace_dir' && PATH='$test_bin:$PATH' bash '$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh' python-deps"

    assert_success
    run grep -c '^uv-remove:' "$log_file"
    assert_output '1'
    run grep -c '^uv-add:' "$log_file"
    assert_output '1'
    run grep -F 'dev = ["pytest>=7.9.9,<8", "ruff>=0.13.0,<0.2"]' "$workspace_dir/pyproject.toml"
    assert_success
}
