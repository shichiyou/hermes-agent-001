#!/usr/bin/env bats

# bats-support と bats-assert をロード
load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

# --------------------------------------------------------------------------
# post-create.sh のテスト
# --------------------------------------------------------------------------

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
# バージョン取得ヘルパー関数のテスト
# --------------------------------------------------------------------------

@test "normalize_version extracts from version string" {
    source "$BATS_TEST_DIRNAME/functions.bash"
    run normalize_version "ollama version is 0.5.6"
    assert_output "0.5.6"
}

@test "versions_match returns true for matching versions" {
    source "$BATS_TEST_DIRNAME/functions.bash"
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '1.2.3' '1.2.3' && echo '0' || echo '1'"
    assert_output "0"
}

@test "versions_match returns false for different versions" {
    source "$BATS_TEST_DIRNAME/functions.bash"
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && versions_match '1.2.3' '1.2.4' && echo '0' || echo '1'"
    assert_output "1"
}

# --------------------------------------------------------------------------
# ワークスペースツールバージョンテストのテスト
# --------------------------------------------------------------------------

@test "workspace_node_tool_path returns path for installed tool" {
    local workspace_dir="$TEST_TMPDIR"
    mkdir -p "$workspace_dir/node_modules/.bin"
    echo '#!/bin/bash
echo "1.2.3"' > "$workspace_dir/node_modules/.bin/test-tool"
    chmod +x "$workspace_dir/node_modules/.bin/test-tool"

    if [ -x "$workspace_dir/node_modules/.bin/test-tool" ]; then
        echo "$workspace_dir/node_modules/.bin/test-tool"
    fi

    assert [ -x "$workspace_dir/node_modules/.bin/test-tool" ]
}

@test "workspace_node_tool_version returns version for installed tool" {
    local workspace_dir="$TEST_TMPDIR"
    mkdir -p "$workspace_dir/node_modules/.bin"
    echo '#!/bin/bash
echo "1.2.3"' > "$workspace_dir/node_modules/.bin/test-tool"
    chmod +x "$workspace_dir/node_modules/.bin/test-tool"

    if [ -x "$workspace_dir/node_modules/.bin/test-tool" ]; then
        run bash -c "$workspace_dir/node_modules/.bin/test-tool --version 2>/dev/null | head -1"
        assert_output "1.2.3"
    else
        fail "test-tool not installed"
    fi
}

@test "workspace_python_tool_version returns version for installed tool" {
    local workspace_dir="$TEST_TMPDIR"
    mkdir -p "$workspace_dir/.venv/bin"
    echo '#!/bin/bash
echo "7.0.1"' > "$workspace_dir/.venv/bin/pytest"
    chmod +x "$workspace_dir/.venv/bin/pytest"

    if [ -x "$workspace_dir/.venv/bin/pytest" ]; then
        run bash -c "$workspace_dir/.venv/bin/pytest --version 2>/dev/null | head -1"
        assert_output "7.0.1"
    else
        fail "pytest not installed"
    fi
}

# --------------------------------------------------------------------------
# update_tool() error-path tests
# --------------------------------------------------------------------------

@test "update_tool returns error for unknown tool" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash' && update_tool 'unknown-tool-xyz'"
    assert_failure
    assert_output --partial "Unknown tool"
}

@test "post-create refreshes lockfiles before syncing dependencies" {
    local sandbox_repo="$TEST_TMPDIR/repo"
    local sandbox_devcontainer="$sandbox_repo/.devcontainer"
    local sandbox_lib_dir="$sandbox_devcontainer/scripts/lib"
    local test_bin="$TEST_TMPDIR/bin"
    local npm_global_prefix="$TEST_TMPDIR/npm-global"
    local log_file="$TEST_TMPDIR/post-create.log"
    local real_node
    local real_python3

    mkdir -p "$sandbox_lib_dir" "$test_bin" "$npm_global_prefix/bin"
    real_node="$(command -v node)"
    real_python3="$(command -v python3)"
    cp "$BATS_TEST_DIRNAME/../.devcontainer/post-create.sh" "$sandbox_devcontainer/post-create.sh"
    cp "$BATS_TEST_DIRNAME/../.devcontainer/scripts/lib/"*.sh "$sandbox_lib_dir/"
    chmod +x "$sandbox_devcontainer/post-create.sh"

    cat > "$sandbox_repo/package.json" <<'EOF'
{
    "name": "workspace",
    "packageManager": "npm@11.12.1",
    "devDependencies": {
        "vite": "^1.0.0"
    }
}
EOF
    printf '{"lockfileVersion":3}\n' > "$sandbox_repo/package-lock.json"
    cat > "$sandbox_repo/pyproject.toml" <<'EOF'
[project]
name = "workspace"
version = "0.0.0"

[dependency-groups]
dev = ["pytest>=7,<8"]
EOF
    printf 'version = 1\n' > "$sandbox_repo/uv.lock"
    cat > "$sandbox_devcontainer/devcontainer.json" <<'EOF'
{
    "features": {
        "ghcr.io/devcontainers/features/node:1": {
            "version": "24"
        },
        "ghcr.io/devcontainers/features/python:1": {
            "version": "3.14"
        }
    }
}
EOF
    create_workspace_node_tools "$sandbox_repo"
    create_workspace_python_tools "$sandbox_repo"

    cat > "$test_bin/sudo" <<'EOF'
#!/bin/bash
"$@"
EOF
    chmod +x "$test_bin/sudo"

    cat > "$test_bin/install" <<EOF
#!/bin/bash
echo "sudo-install" >> "$log_file"
exit 0
EOF
    chmod +x "$test_bin/install"

    cat > "$test_bin/node" <<EOF
#!/bin/bash
case "\$1" in
    --version)
        echo "v24.0.0"
        ;;
    *)
        exec "$real_node" "\$@"
        ;;
esac
EOF
    chmod +x "$test_bin/node"

    cat > "$test_bin/npm" <<EOF
#!/bin/bash
case "\$1" in
    --version)
        echo "11.13.0"
        ;;
    view)
        case "\$2" in
            npm)
                echo "11.13.0"
                ;;
            'vite@>=1.0.0 <2.0.0')
                echo "1.9.9"
                ;;
            *)
                echo "unexpected npm view invocation: \$*" >&2
                exit 1
                ;;
        esac
        ;;
    update)
        echo "npm-update" >> "$log_file"
        ;;
    ci)
        echo "npm-ci" >> "$log_file"
        ;;
    install)
        if [[ " \$* " == *" vite@1.9.9 "* ]]; then
            echo "npm-pin-install" >> "$log_file"
            "$real_node" - "$sandbox_repo/package.json" <<'NODE'
const fs = require('node:fs');

const packageJsonPath = process.argv[2];
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
packageJson.devDependencies.vite = '^1.9.9';
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
NODE
        elif [ "\$2" = "-g" ] && [ "\$3" = "npm@11.13.0" ]; then
            echo "npm-align" >> "$log_file"
        elif [ "\$2" = "-g" ]; then
            echo "npm-global-install" >> "$log_file"
        else
            echo "unexpected npm invocation: \$*" >&2
            exit 1
        fi
        ;;
    prefix)
        echo "$npm_global_prefix"
        ;;
    *)
        echo "unexpected npm invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/npm"

    cat > "$test_bin/uv" <<EOF
#!/bin/bash
case "\$1 \$2" in
    'remove --group')
        echo "uv-remove-dev-pytest" >> "$log_file"
        sed -i 's/dev = \["pytest>=7,<8"\]/dev = []/' "$sandbox_repo/pyproject.toml"
        ;;
    'add --group')
        echo "uv-add-dev-pytest" >> "$log_file"
        sed -i 's/dev = \[\]/dev = ["pytest>=9.0.2"]/' "$sandbox_repo/pyproject.toml"
        ;;
    'lock --upgrade')
        echo "uv-lock-upgrade" >> "$log_file"
        ;;
    'sync --dev')
        echo "uv-sync-dev" >> "$log_file"
        ;;
    '--version ')
        echo "uv 0.6.0"
        ;;
    *)
        echo "unexpected uv invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/uv"

    cat > "$test_bin/curl" <<'EOF'
#!/bin/bash
case "$1" in
    -fsSL)
        case "$2" in
            https://nodejs.org/dist/index.json)
                cat <<'JSON'
[
  {"version":"v24.9.0","lts":"Iron"},
  {"version":"v26.1.0","lts":"Jod"}
]
JSON
                ;;
            https://www.python.org/ftp/python/)
                cat <<'HTML'
<a href="3.14.3/">3.14.3/</a>
<a href="3.15.0/">3.15.0/</a>
HTML
                ;;
            *)
                echo "unexpected curl URL: $2" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "unexpected curl invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$test_bin/curl"

    cat > "$test_bin/git" <<'EOF'
#!/bin/bash
echo "git version 2.49.0"
EOF
    chmod +x "$test_bin/git"

    cat > "$test_bin/az" <<'EOF'
#!/bin/bash
echo "2.80.0"
EOF
    chmod +x "$test_bin/az"

    cat > "$test_bin/gh" <<'EOF'
#!/bin/bash
echo "gh version 2.80.0"
EOF
    chmod +x "$test_bin/gh"

    cat > "$test_bin/docker" <<'EOF'
#!/bin/bash
if [ "$1" = "compose" ] && [ "$2" = "version" ]; then
    echo "Docker Compose version v2.40.0"
else
    echo "Docker version 28.0.0"
fi
EOF
    chmod +x "$test_bin/docker"

    cat > "$test_bin/python3" <<EOF
#!/bin/bash
case "\$1" in
    --version)
        echo "Python 3.14.0"
        ;;
    *)
        exec "$real_python3" "\$@"
        ;;
esac
EOF
    chmod +x "$test_bin/python3"

    cat > "$test_bin/claude" <<'EOF'
#!/bin/bash
echo "claude 1.0.0"
EOF
    chmod +x "$test_bin/claude"

    cat > "$test_bin/codex" <<'EOF'
#!/bin/bash
echo "codex 1.0.0"
EOF
    chmod +x "$test_bin/codex"

    cat > "$test_bin/ollama" <<'EOF'
#!/bin/bash
echo "ollama version is 0.5.6"
EOF
    chmod +x "$test_bin/ollama"

    cat > "$npm_global_prefix/bin/copilot" <<'EOF'
#!/bin/bash
echo "copilot 1.0.0"
EOF
    chmod +x "$npm_global_prefix/bin/copilot"

    run bash -c "cd '$sandbox_repo' && PATH='$test_bin:$PATH' bash '$sandbox_devcontainer/post-create.sh'"

    assert_success
    run grep -E '^(npm-pin-install|npm-update|npm-ci|uv-remove-dev-pytest|uv-add-dev-pytest|uv-lock-upgrade|uv-sync-dev)$' "$log_file"
    assert_success
    assert_output $'npm-pin-install\nuv-remove-dev-pytest\nuv-add-dev-pytest\nnpm-update\nnpm-ci\nuv-lock-upgrade\nuv-sync-dev'
    run grep -F '"packageManager": "npm@11.13.0"' "$sandbox_repo/package.json"
    assert_success
    run grep -F '"vite": "^1.9.9"' "$sandbox_repo/package.json"
    assert_success
    run grep -F 'dev = ["pytest>=9.0.2"]' "$sandbox_repo/pyproject.toml"
    assert_success
    run grep -F '"version": "26"' "$sandbox_devcontainer/devcontainer.json"
    assert_success
    run grep -F '"version": "3.14"' "$sandbox_devcontainer/devcontainer.json"
    assert_success
}
