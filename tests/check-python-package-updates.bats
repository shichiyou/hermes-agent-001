#!/usr/bin/env bats

load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

CHECK_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/check-python-package-updates.sh"
UPDATE_TOOLS_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh"

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TMPDIR/home"
    export HOME="$TEST_HOME"
    export FAKE_UV_FIXTURES_DIR="$TEST_TMPDIR/uv-fixtures"
    export PATH="$TEST_TMPDIR/bin:$PATH"
    export PYTHON_DEP_CHECK_PYTHON="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/.venv/bin/python"

    mkdir -p "$TEST_HOME/.cache" "$TEST_HOME/.local/state" "$TEST_TMPDIR/bin" "$FAKE_UV_FIXTURES_DIR"

    write_fake_uv
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

write_fake_uv() {
    cat > "$TEST_TMPDIR/bin/uv" <<'EOF'
#!/bin/sh
set -eu

emit_fixture() {
    fixture_name="$1"
    fixture_base="$FAKE_UV_FIXTURES_DIR/$fixture_name"

    if [ -f "$fixture_base.stderr" ]; then
        cat "$fixture_base.stderr" >&2
    fi

    if [ -f "$fixture_base.stdout" ]; then
        cat "$fixture_base.stdout"
    fi

    if [ -f "$fixture_base.status" ]; then
        status="$(cat "$fixture_base.status")"
        return "$status"
    fi

    return 0
}

if [ "$1" = "--preview-features" ]; then
    shift 2
fi

command_name="$1"
shift

case "$command_name" in
    pip)
        subcommand="$1"
        shift
        if [ "$subcommand" != "list" ]; then
            echo "unexpected uv pip subcommand: $subcommand" >&2
            exit 2
        fi

        emit_fixture pip-list
        exit "$?"
        ;;
    lock)
        emit_fixture lock-check
        exit "$?"
        ;;
    sync)
        emit_fixture sync-check
        exit "$?"
        ;;
    audit)
        emit_fixture audit
        exit "$?"
        ;;
    *)
        echo "unexpected uv invocation: $command_name $*" >&2
        exit 2
        ;;
esac
EOF

    chmod +x "$TEST_TMPDIR/bin/uv"
}

create_workspace() {
    mkdir -p "$TEST_TMPDIR/workspace"
    cat > "$TEST_TMPDIR/workspace/pyproject.toml" <<'EOF'
[project]
name = "fixture-root"
version = "0.0.0"
requires-python = ">=3.12"

[dependency-groups]
dev = [
    "pytest>=9.0.2,<10",
]
EOF

    cat > "$TEST_TMPDIR/workspace/uv.lock" <<'EOF'
version = 1
revision = 3
requires-python = ">=3.12"
EOF
}

create_workspace_with_member() {
    mkdir -p "$TEST_TMPDIR/workspace/packages/api"
    cat > "$TEST_TMPDIR/workspace/pyproject.toml" <<'EOF'
[project]
name = "fixture-root"
version = "0.0.0"
requires-python = ">=3.12"

[dependency-groups]
dev = [
    "pytest>=9.0.2,<10",
]

[tool.uv.workspace]
members = ["packages/*"]
EOF

    cat > "$TEST_TMPDIR/workspace/packages/api/pyproject.toml" <<'EOF'
[project]
name = "fixture-api"
version = "0.0.0"
requires-python = ">=3.12"
dependencies = [
    "ruff>=0.12.0,<0.13",
]
EOF

    cat > "$TEST_TMPDIR/workspace/uv.lock" <<'EOF'
version = 1
revision = 3
requires-python = ">=3.12"
EOF
}

write_fixture_stdout() {
    local fixture_name="$1"
    local payload="$2"

    printf '%s' "$payload" > "$FAKE_UV_FIXTURES_DIR/$fixture_name.stdout"
}

write_fixture_stderr() {
    local fixture_name="$1"
    local payload="$2"

    printf '%s' "$payload" > "$FAKE_UV_FIXTURES_DIR/$fixture_name.stderr"
}

write_fixture_status() {
    local fixture_name="$1"
    local status_code="$2"

    printf '%s' "$status_code" > "$FAKE_UV_FIXTURES_DIR/$fixture_name.status"
}

write_clean_fixtures() {
    write_fixture_stdout pip-list '[]'
    write_fixture_status pip-list 0
    write_fixture_status lock-check 0
    write_fixture_status sync-check 0
    write_fixture_stdout audit 'Found no known vulnerabilities and no adverse project statuses in 6 packages'
    write_fixture_status audit 0
}

@test "check-python-package-updates: exits 0 when nothing needs attention" {
    create_workspace
    write_clean_fixtures

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_success
    assert_output --partial 'Checked manifests:'
    assert_output --partial '  - .'
    assert_output --partial 'Pyproject spec updates needed:'
    assert_output --partial 'uv.lock refreshes available within current specifiers:'
    assert_output --partial 'Summary: no Python dependency updates or security findings detected.'
}

@test "check-python-package-updates: separates spec updates from lock refreshes" {
    create_workspace_with_member
    write_clean_fixtures
    write_fixture_stdout pip-list '[{"name":"pytest","version":"9.0.2","latest_version":"9.0.3"},{"name":"ruff","version":"0.12.8","latest_version":"0.13.0"}]'

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial 'Pyproject spec updates needed:'
    assert_output --partial 'packages/api: ruff (current: 0.12.8, latest: 0.13.0, specifier: <0.13,>=0.12.0)'
    assert_output --partial 'uv.lock refreshes available within current specifiers:'
    assert_output --partial '.:dev: pytest (current: 9.0.2, latest: 9.0.3, specifier: <10,>=9.0.2)'
}

@test "check-python-package-updates: reports lockfile drift and environment sync drift" {
    create_workspace
    write_clean_fixtures
    write_fixture_status lock-check 1
    write_fixture_status sync-check 1

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial 'uv.lock is not up to date with pyproject.toml. Run uv lock.'
    assert_output --partial 'Project environment is not synchronized with uv.lock. Run uv sync --dev.'
}

@test "check-python-package-updates: reports uv audit findings" {
    create_workspace
    write_clean_fixtures
    write_fixture_stdout audit 'PYSEC-2026-1: pytest vulnerable in fixture output'
    write_fixture_status audit 1

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial 'Security findings:'
    assert_output --partial 'PYSEC-2026-1: pytest vulnerable in fixture output'
}

@test "check-python-package-updates: returns 2 when uv pip list fails" {
    create_workspace
    write_clean_fixtures
    write_fixture_stderr pip-list 'could not reach index'
    write_fixture_status pip-list 2

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '2'
    assert_output --partial 'Failed to query uv pip list for outdated packages.'
}

@test "update-tools: routes python-deps-check to the standalone checker" {
    create_workspace
    write_clean_fixtures

    run bash -c "cd '$TEST_TMPDIR/workspace' && PATH='$TEST_TMPDIR/bin:$PATH' bash '$UPDATE_TOOLS_SCRIPT' python-deps-check"

    assert_success
    assert_output --partial '[python-deps-check]'
    assert_output --partial 'Summary: no Python dependency updates or security findings detected.'
}
