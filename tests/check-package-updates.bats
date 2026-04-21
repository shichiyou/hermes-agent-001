#!/usr/bin/env bats

load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

CHECK_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/check-package-updates.sh"
UPDATE_TOOLS_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/scripts/update-tools.sh"

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TMPDIR/home"
    export HOME="$TEST_HOME"
    export FAKE_NPM_FIXTURES_DIR="$TEST_TMPDIR/npm-fixtures"
    export PATH="$TEST_TMPDIR/bin:$PATH"

    mkdir -p "$TEST_HOME/.cache" "$TEST_HOME/.local/state" "$TEST_TMPDIR/bin" "$FAKE_NPM_FIXTURES_DIR"

    write_fake_npm
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

write_fake_npm() {
    cat > "$TEST_TMPDIR/bin/npm" <<'EOF'
#!/bin/sh
set -eu

sanitize_key() {
    printf '%s' "$1" | tr '/:' '__'
}

emit_fixture() {
    fixture_name="$1"
    fixture_base="$FAKE_NPM_FIXTURES_DIR/$fixture_name"

    if [ -f "$fixture_base.stderr" ]; then
        cat "$fixture_base.stderr" >&2
    fi

    if [ -f "$fixture_base.json" ]; then
        cat "$fixture_base.json"
    fi

    if [ -f "$fixture_base.status" ]; then
        status="$(cat "$fixture_base.status")"
        return "$status"
    fi

    return 0
}

command_name="$1"
shift

case "$command_name" in
    outdated)
        workspace='.'
        while [ $# -gt 0 ]; do
            case "$1" in
                --workspace)
                    shift
                    workspace="$1"
                    ;;
                --json|--workspaces=false)
                    ;;
                *)
                    echo "unexpected outdated arg: $1" >&2
                    exit 2
                    ;;
            esac
            shift
        done

        fixture_name='outdated-root'
        if [ "$workspace" != "." ]; then
            fixture_name="outdated-$(sanitize_key "$workspace")"
        fi

        emit_fixture "$fixture_name"
        exit "$?"
        ;;
    audit)
        while [ $# -gt 0 ]; do
            case "$1" in
                --json)
                    ;;
                *)
                    echo "unexpected audit arg: $1" >&2
                    exit 2
                    ;;
            esac
            shift
        done

        emit_fixture audit
        exit "$?"
        ;;
    *)
        echo "unexpected npm invocation: $command_name $*" >&2
        exit 2
        ;;
esac
EOF

    chmod +x "$TEST_TMPDIR/bin/npm"
}

create_workspace() {
    local workspaces_json="${1:-[]}"

    mkdir -p "$TEST_TMPDIR/workspace"
    cat > "$TEST_TMPDIR/workspace/package.json" <<EOF
{
  "name": "fixture-root",
  "private": true,
  "workspaces": $workspaces_json
}
EOF
}

create_workspace_package() {
    local relative_dir="$1"
    local package_name="$2"

    mkdir -p "$TEST_TMPDIR/workspace/$relative_dir"
    cat > "$TEST_TMPDIR/workspace/$relative_dir/package.json" <<EOF
{
  "name": "$package_name"
}
EOF
}

write_fixture_json() {
    local fixture_name="$1"
    local json_payload="$2"

    printf '%s' "$json_payload" > "$FAKE_NPM_FIXTURES_DIR/$fixture_name.json"
}

write_fixture_status() {
    local fixture_name="$1"
    local status_code="$2"

    printf '%s' "$status_code" > "$FAKE_NPM_FIXTURES_DIR/$fixture_name.status"
}

write_fixture_stderr() {
    local fixture_name="$1"
    local stderr_payload="$2"

    printf '%s' "$stderr_payload" > "$FAKE_NPM_FIXTURES_DIR/$fixture_name.stderr"
}

write_clean_audit_fixture() {
    write_fixture_json audit '{"metadata":{"vulnerabilities":{"info":0,"low":0,"moderate":0,"high":0,"critical":0,"total":0}}}'
    write_fixture_status audit 0
}

@test "check-package-updates: exits 0 when nothing needs attention" {
    create_workspace
    write_fixture_json outdated-root '{}'
    write_fixture_status outdated-root 0
    write_clean_audit_fixture

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_success
    assert_output --partial 'Checked manifests:'
    assert_output --partial '  - .'
    assert_output --partial 'Package.json range updates needed:'
    assert_output --partial 'Lockfile / node_modules sync needed:'
    assert_output --partial 'Summary: no package updates or security findings detected.'
}

@test "check-package-updates: separates range updates from sync-only updates" {
    create_workspace
    write_fixture_json outdated-root '{"turbo":{"current":"2.8.0","wanted":"2.9.3","latest":"2.9.3"},"typescript":{"current":"5.9.2","wanted":"5.9.3","latest":"6.0.2"}}'
    write_fixture_status outdated-root 1
    write_clean_audit_fixture

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial 'Package.json range updates needed:'
    assert_output --partial '.: typescript (current: 5.9.2, wanted: 5.9.3, latest: 6.0.2)'
    assert_output --partial 'Lockfile / node_modules sync needed:'
    assert_output --partial '.: turbo (current: 2.8.0, wanted: 2.9.3, latest: 2.9.3)'
}

@test "check-package-updates: reports npm audit findings" {
    create_workspace
    write_fixture_json outdated-root '{}'
    write_fixture_status outdated-root 0
    write_fixture_json audit '{"metadata":{"vulnerabilities":{"info":0,"low":1,"moderate":2,"high":1,"critical":0,"total":4}}}'
    write_fixture_status audit 1

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial 'Security findings:'
    assert_output --partial 'total: 4 (info: 0, low: 1, moderate: 2, high: 1, critical: 0)'
}

@test "check-package-updates: resolves the monorepo root from inside a workspace package" {
    create_workspace '["apps/*"]'
    create_workspace_package 'apps/web' 'fixture-web'
    mkdir -p "$TEST_TMPDIR/workspace/apps/web/src"
    write_fixture_json outdated-root '{}'
    write_fixture_status outdated-root 0
    write_fixture_json outdated-apps_web '{"vite":{"current":"8.0.0","wanted":"8.0.7","latest":"8.0.7"}}'
    write_fixture_status outdated-apps_web 1
    write_clean_audit_fixture

    run bash -c "cd '$TEST_TMPDIR/workspace/apps/web/src' && '$CHECK_SCRIPT'"

    assert_equal "$status" '1'
    assert_output --partial "Workspace root: $TEST_TMPDIR/workspace"
    assert_output --partial '  - apps/web'
    assert_output --partial 'apps/web: vite (current: 8.0.0, wanted: 8.0.7, latest: 8.0.7)'
}

@test "check-package-updates: returns 2 when npm outdated fails" {
    create_workspace
    write_fixture_status outdated-root 2
    write_fixture_stderr outdated-root 'npm registry unavailable'
    write_clean_audit_fixture

    run bash -c "cd '$TEST_TMPDIR/workspace' && '$CHECK_SCRIPT'"

    assert_equal "$status" '2'
    assert_output --partial 'Failed to query npm outdated for .'
}

@test "update-tools: routes node-deps-check to the standalone checker" {
    create_workspace
    write_fixture_json outdated-root '{}'
    write_fixture_status outdated-root 0
    write_clean_audit_fixture

    run bash -c "cd '$TEST_TMPDIR/workspace' && PATH='$TEST_TMPDIR/bin:$PATH' bash '$UPDATE_TOOLS_SCRIPT' node-deps-check"

    assert_success
    assert_output --partial '[node-deps-check]'
    assert_output --partial 'Summary: no package updates or security findings detected.'
}
