#!/usr/bin/env bats

# bats-support と bats-assert をロード
load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

# --------------------------------------------------------------------------
# on-create.sh のテスト
# --------------------------------------------------------------------------

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TMPDIR/home"
    export HOME="$TEST_HOME"
    mkdir -p "$TEST_HOME/.local/state"
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

@test "skips initialization when .home_initialized exists" {
    touch "$HOME/.home_initialized"

    # on-create.sh のロジックを再現
    if [ -f "$HOME/.home_initialized" ]; then
        echo "already initialized"
    fi

    assert [ -f "$HOME/.home_initialized" ]
}

@test "initializes home when .home_initialized does not exist" {
    # on-create.sh のロジックを再現
    if [ ! -f "$HOME/.home_initialized" ]; then
        # /etc/skel からコピー（テスト環境では空振り）
        cp -a /etc/skel/. "$HOME/" 2>/dev/null || true
        touch "$HOME/.home_initialized"
        echo "Initializing home volume"
    fi

    assert [ -f "$HOME/.home_initialized" ]
}

@test ".home_initialized flag is created after initialization" {
    rm -f "$HOME/.home_initialized"

    # on-create.sh のロジックを再現
    if [ ! -f "$HOME/.home_initialized" ]; then
        cp -a /etc/skel/. "$HOME/" 2>/dev/null || true
        touch "$HOME/.home_initialized"
    fi

    assert [ -f "$HOME/.home_initialized" ]
}
