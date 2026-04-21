#!/usr/bin/env bats

# bats-support と bats-assert をロード
load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

# --------------------------------------------------------------------------
# post-start.sh のテスト
# --------------------------------------------------------------------------

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TMPDIR/home"
    export TEST_BIN_DIR="$TEST_TMPDIR/bin"
    export HOME="$TEST_HOME"
    export XDG_STATE_HOME="$TEST_HOME/.local"
    export OLLAMA_STARTUP_RETRY_INTERVAL=0
    export FAKE_OLLAMA_READY_FILE="$TEST_TMPDIR/ollama-ready"
    export FAKE_OLLAMA_STARTED_FILE="$TEST_TMPDIR/ollama-started"
    export FAKE_CURL_ATTEMPTS_FILE="$TEST_TMPDIR/curl-attempts"
    export PATH="$TEST_BIN_DIR:$PATH"
    mkdir -p "$TEST_BIN_DIR" "$XDG_STATE_HOME/ollama"
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

@test "post-start script completes when Ollama must be started" {
    local test_bin="$TEST_TMPDIR/bin"
    local state_file="$TEST_TMPDIR/ollama-started"
    mkdir -p "$test_bin"

    cat >"$test_bin/curl" <<EOF
#!/bin/bash
if [[ -f "$state_file" ]]; then
    exit 0
fi
exit 1
EOF

    cat >"$test_bin/ollama" <<EOF
#!/bin/bash
if [[ "\$1" == "serve" ]]; then
    touch "$state_file"
    exit 0
fi
exit 1
EOF

    cat >"$test_bin/nohup" <<'EOF'
#!/bin/bash
exec "$@"
EOF

    cat >"$test_bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

    chmod +x "$test_bin/curl" "$test_bin/ollama" "$test_bin/nohup" "$test_bin/sleep"

    run env PATH="$test_bin:$PATH" bash "$BATS_TEST_DIRNAME/../.devcontainer/post-start.sh"

    assert_success
    assert [ -f "$state_file" ]
    assert [ -f "$XDG_STATE_HOME/ollama/post-start.log" ]
    assert_output --partial "Post-start setup complete."
}

@test "creates log directory" {
    assert [ -d "$XDG_STATE_HOME/ollama" ]
}

@test "creates post-start.log file after sourcing post-start" {
    # post-start.sh を source して実行
    OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
    OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-262144}"
    OLLAMA_URL="http://${OLLAMA_HOST}/api/tags"
    OLLAMA_LOG_DIR="$XDG_STATE_HOME/ollama"
    OLLAMA_LOG_FILE="$OLLAMA_LOG_DIR/server.log"
    POST_START_LOG_FILE="$OLLAMA_LOG_DIR/post-start.log"

    log() {
        local message="$1"
        local timestamp
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        printf '[%s] %s\n' "$timestamp" "$message" | tee -a "$POST_START_LOG_FILE"
    }

    log "test message"
    assert [ -f "$POST_START_LOG_FILE" ]
}

@test "removes legacy gateway auto-start from bashrc" {
    cat >"$HOME/.bashrc" <<'EOF'
# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-template/wiki"

# Start Hermes Gateway if not running to ensure cronjobs execute
if ! pgrep -f "hermes gateway" > /dev/null; then
    nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
fi

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac
EOF

    cat >"$TEST_BIN_DIR/curl" <<'EOF'
#!/bin/bash
if [[ "$1" == "-fsS" && "$2" == "http://127.0.0.1:11434/api/tags" ]]; then
    exit 0
fi
exit 1
EOF

    chmod +x "$TEST_BIN_DIR/curl"

    run bash "$BATS_TEST_DIRNAME/../.devcontainer/post-start.sh"

    assert_success
    run grep -F 'nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &' "$HOME/.bashrc"
    assert_failure
    run grep -F "Removed legacy Hermes Gateway auto-start from ~/.bashrc." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success
}

@test "removes stale gateway state before starting hermes gateway" {
    mkdir -p "$HOME/.hermes"
    cat >"$HOME/.hermes/gateway.pid" <<'EOF'
{"pid": 2849, "kind": "hermes-gateway", "argv": ["/home/vscode/.local/bin/hermes", "gateway"], "start_time": 3737770}
EOF
    cat >"$HOME/.hermes/gateway_state.json" <<'EOF'
{"pid": 2849, "kind": "hermes-gateway", "argv": ["/home/vscode/.local/bin/hermes", "gateway"], "start_time": 3737770, "gateway_state": "running"}
EOF

    cat >"$TEST_BIN_DIR/curl" <<'EOF'
#!/bin/bash
if [[ "$1" == "-fsS" ]]; then
    case "$2" in
        http://127.0.0.1:11434/api/tags)
            exit 0
            ;;
        http://127.0.0.1:9119/)
            exit 0
            ;;
    esac
fi
exit 1
EOF

    cat >"$TEST_BIN_DIR/hermes" <<'EOF'
#!/bin/bash
if [[ "$1" == "gateway" ]]; then
    : > "$TEST_TMPDIR/hermes-gateway-started"
    exit 0
fi
if [[ "$1" == "dashboard" ]]; then
    exit 0
fi
exit 1
EOF

    cat >"$TEST_BIN_DIR/nohup" <<'EOF'
#!/bin/bash
exec "$@"
EOF

    cat >"$TEST_BIN_DIR/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF

    cat >"$TEST_BIN_DIR/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

    cat >"$TEST_BIN_DIR/flock" <<'EOF'
#!/bin/bash
if [[ "$1" == "-u" ]]; then
    exit 0
fi
exit 0
EOF

    chmod +x "$TEST_BIN_DIR/curl" "$TEST_BIN_DIR/hermes" "$TEST_BIN_DIR/nohup" "$TEST_BIN_DIR/pgrep" "$TEST_BIN_DIR/sleep" "$TEST_BIN_DIR/flock"

    run bash "$BATS_TEST_DIRNAME/../.devcontainer/post-start.sh"

    assert_success
    assert [ ! -f "$HOME/.hermes/gateway.pid" ]
    assert [ ! -f "$HOME/.hermes/gateway_state.json" ]
    assert [ -f "$TEST_TMPDIR/hermes-gateway-started" ]
    run grep -F "Removed stale Hermes Gateway state files for PID 2849." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success
}

@test "runs successfully when Ollama must be started" {
    cat >"$TEST_BIN_DIR/curl" <<'EOF'
#!/bin/bash
if [ ! -f "$FAKE_OLLAMA_STARTED_FILE" ]; then
    exit 1
fi

attempts="$(cat "$FAKE_CURL_ATTEMPTS_FILE" 2>/dev/null || echo 0)"
attempts=$((attempts + 1))
printf '%s\n' "$attempts" > "$FAKE_CURL_ATTEMPTS_FILE"

if [ "$attempts" -ge 2 ]; then
    : > "$FAKE_OLLAMA_READY_FILE"
    exit 0
fi

exit 1
EOF

    cat >"$TEST_BIN_DIR/ollama" <<'EOF'
#!/bin/bash
if [ "$1" = "serve" ]; then
    : > "$FAKE_OLLAMA_STARTED_FILE"
    exit 0
fi

exit 1
EOF

    chmod +x "$TEST_BIN_DIR/curl" "$TEST_BIN_DIR/ollama"

    run bash "$BATS_TEST_DIRNAME/../.devcontainer/post-start.sh"

    assert_success
    assert [ -f "$FAKE_OLLAMA_STARTED_FILE" ]
    assert [ -f "$FAKE_OLLAMA_READY_FILE" ]
    assert [ -f "$FAKE_CURL_ATTEMPTS_FILE" ]
    assert [ -f "$XDG_STATE_HOME/ollama/post-start.log" ]

    run cat "$FAKE_CURL_ATTEMPTS_FILE"
    assert_output "2"

    run grep -F "Starting Ollama server..." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success

    run grep -F "Ollama startup confirmed." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success
}

@test "creates hermes log directory before starting gateway and dashboard" {
    cat >"$TEST_BIN_DIR/curl" <<'EOF'
#!/bin/bash
if [[ "$1" == "-fsS" ]]; then
    case "$2" in
        http://127.0.0.1:11434/api/tags)
            exit 0
            ;;
        http://127.0.0.1:9119/)
            exit 0
            ;;
    esac
fi
exit 1
EOF

    cat >"$TEST_BIN_DIR/hermes" <<'EOF'
#!/bin/bash
if [[ "$1" == "gateway" || "$1" == "dashboard" ]]; then
    exit 0
fi
exit 1
EOF

    cat >"$TEST_BIN_DIR/nohup" <<'EOF'
#!/bin/bash
exec "$@"
EOF

    cat >"$TEST_BIN_DIR/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF

    cat >"$TEST_BIN_DIR/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

    chmod +x "$TEST_BIN_DIR/curl" "$TEST_BIN_DIR/hermes" "$TEST_BIN_DIR/nohup" "$TEST_BIN_DIR/pgrep" "$TEST_BIN_DIR/sleep"

    run bash "$BATS_TEST_DIRNAME/../.devcontainer/post-start.sh"

    assert_success
    assert [ -d "$XDG_STATE_HOME/hermes" ]
    assert [ -f "$XDG_STATE_HOME/hermes/gateway.log" ]
    assert [ -f "$XDG_STATE_HOME/hermes/dashboard.log" ]

    run grep -F "Starting Hermes Gateway..." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success

    run grep -F "Hermes Dashboard is responding on port 9119." "$XDG_STATE_HOME/ollama/post-start.log"
    assert_success
}

@test "uses default OLLAMA_CONTEXT_LENGTH of 262144" {
    unset OLLAMA_CONTEXT_LENGTH
    export OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-262144}"
    assert_equal "$OLLAMA_CONTEXT_LENGTH" "262144"
}

@test "respects custom OLLAMA_CONTEXT_LENGTH" {
    export OLLAMA_CONTEXT_LENGTH=131072
    assert_equal "$OLLAMA_CONTEXT_LENGTH" "131072"
}

@test "OLLAMA_URL is correctly formatted" {
    OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
    OLLAMA_URL="http://${OLLAMA_HOST}/api/tags"
    assert_equal "$OLLAMA_URL" "http://127.0.0.1:11434/api/tags"
}

@test "OLLAMA_URL respects custom OLLAMA_HOST" {
    export OLLAMA_HOST="0.0.0.0:11434"
    OLLAMA_URL="http://${OLLAMA_HOST}/api/tags"
    assert_equal "$OLLAMA_URL" "http://0.0.0.0:11434/api/tags"
}
