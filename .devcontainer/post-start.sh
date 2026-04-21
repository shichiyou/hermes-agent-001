#!/bin/bash
# SPDX-License-Identifier: MIT
# ==========================================================================
# post-start.sh — Runs on every container start (postStartCommand)
# Starts long-running auxiliary services as needed
# ==========================================================================
set -euo pipefail

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${SCRIPT_DIR}/scripts/lib"
# shellcheck source=/dev/null
source "${_LIB_DIR}/logging.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/retry.sh"

OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-262144}"
OLLAMA_URL="http://${OLLAMA_HOST}/api/tags"
OLLAMA_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ollama"
OLLAMA_LOG_FILE="${OLLAMA_LOG_DIR}/server.log"

log_init "${OLLAMA_LOG_DIR}/post-start.log"

log_info "Post-start setup began."

cleanup_stale_gateway_state() {
    local gateway_pid_file="$HOME/.hermes/gateway.pid"
    local gateway_state_file="$HOME/.hermes/gateway_state.json"
    local gateway_pid

    if [ ! -f "$gateway_pid_file" ]; then
        return 0
    fi

    gateway_pid="$(sed -n 's/.*"pid": \([0-9][0-9]*\).*/\1/p' "$gateway_pid_file" | head -n 1)"
    if [ -z "$gateway_pid" ]; then
        return 0
    fi

    if ! kill -0 "$gateway_pid" 2>/dev/null; then
        rm -f "$gateway_pid_file" "$gateway_state_file"
        log_info "Removed stale Hermes Gateway state files for PID ${gateway_pid}."
    fi
}

remove_legacy_bashrc_gateway_autostart() {
    local bashrc_path="$HOME/.bashrc"
    local temp_file

    if [ ! -f "$bashrc_path" ]; then
        return 0
    fi

    temp_file="$(mktemp)"
    awk '
        BEGIN {
            removed = 0
        }
        {
            if ($0 == "# Start Hermes Gateway if not running to ensure cronjobs execute") {
                if (getline line2 <= 0) {
                    print $0
                    next
                }
                if (getline line3 <= 0) {
                    print $0
                    print line2
                    next
                }
                if (getline line4 <= 0) {
                    print $0
                    print line2
                    print line3
                    next
                }
                if (line2 == "if ! pgrep -f \"hermes gateway\" > /dev/null; then" &&
                    line3 == "    nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &" &&
                    line4 == "fi") {
                    removed = 1
                    next
                }
                print $0
                print line2
                print line3
                print line4
                next
            }
            print $0
        }
        END {
            if (removed == 0) {
                exit 0
            }
        }
    ' "$bashrc_path" > "$temp_file"

    if ! cmp -s "$bashrc_path" "$temp_file"; then
        mv "$temp_file" "$bashrc_path"
        log_info "Removed legacy Hermes Gateway auto-start from ~/.bashrc."
    else
        rm -f "$temp_file"
    fi
}

remove_legacy_bashrc_gateway_autostart

ollama_api_ready() {
    curl -fsS "$OLLAMA_URL" >/dev/null 2>&1
}

wait_for_ollama_startup() {
    local retries="${OLLAMA_STARTUP_RETRIES:-5}"
    local retry_interval="${OLLAMA_STARTUP_RETRY_INTERVAL:-1}"

    RETRY_INTERVAL="$retry_interval" retry "$retries" ollama_api_ready
}

if ollama_api_ready; then
    log_info "Ollama server is already running."
else
    log_info "Starting Ollama server..."
    nohup env OLLAMA_CONTEXT_LENGTH="$OLLAMA_CONTEXT_LENGTH" ollama serve >"$OLLAMA_LOG_FILE" 2>&1 &

    if wait_for_ollama_startup; then
        log_info "Ollama startup confirmed. Server log: $OLLAMA_LOG_FILE"
    else
        log_warn "Ollama startup requested, but API is not responding yet. Server log: $OLLAMA_LOG_FILE"
    fi
fi

# ------------------------------------------------------------------
# Harden AI CLI credential file permissions.
# Runs on every container start so permissions are enforced even after
# the user logs into an AI CLI post-creation.
# Note: protects against other container processes, but NOT against
# root inside the container or host-level Docker volume inspection.
# ------------------------------------------------------------------
for _dir in "$HOME/.claude" "$HOME/.copilot" "$HOME/.codex"; do
    if [ -d "$_dir" ]; then
        # Best-effort only: permission issues must not break container startup.
        find "$_dir" -type d -exec chmod 700 {} + 2>/dev/null || true
        find "$_dir" -type f -exec chmod 600 {} + 2>/dev/null || true
        log_info "Best-effort permission hardening attempted on ${_dir}"
    fi
done
unset _dir

# ------------------------------------------------------------------
# AI CLI log rotation (controlled by AI_LOG_RETENTION_DAYS, default 30)
# Rotates ~/.copilot/logs/ on every container start.
# Conversation history (~/.claude/, ~/.codex/) is NOT rotated automatically
# because it serves as working context; remove manually when no longer needed.
# ------------------------------------------------------------------
_retention_days="${AI_LOG_RETENTION_DAYS:-30}"

if [ -d "$HOME/.copilot/logs" ]; then
    find "$HOME/.copilot/logs" -type f -mtime +"${_retention_days}" -delete 2>/dev/null || true
    log_info "Rotated ~/.copilot/logs (retention: ${_retention_days} days)"
fi

_post_start_log="${OLLAMA_LOG_DIR}/post-start.log"
if [ -f "$_post_start_log" ]; then
    _log_size="$(stat -c%s "$_post_start_log" 2>/dev/null || echo 0)"
    if [ "$_log_size" -gt 5242880 ]; then
        : > "$_post_start_log"
        log_info "Truncated post-start.log (exceeded 5 MB)"
    fi
fi
unset _retention_days _post_start_log _log_size

# ------------------------------------------------------------------
# Hermes Gateway & Dashboard auto-start
# Starts the messaging gateway (required for cron jobs and platform
# integrations) and the web dashboard for configuration management.
# Runs after Ollama so that local model endpoints are available.
# ------------------------------------------------------------------
HERMES_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hermes"
HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"
HERMES_GATEWAY_LOCK_FILE="${HERMES_LOG_DIR}/gateway-start.lock"

if command -v hermes >/dev/null 2>&1; then
    mkdir -p "$HERMES_LOG_DIR"
    cleanup_stale_gateway_state

    # Gateway
    exec 9>"$HERMES_GATEWAY_LOCK_FILE"
    flock 9
    if ! pgrep -f "hermes gateway" > /dev/null; then
        log_info "Starting Hermes Gateway..."
        nohup hermes gateway > "${HERMES_LOG_DIR}/gateway.log" 2>&1 &
    else
        log_info "Hermes Gateway already running."
    fi
    flock -u 9
    exec 9>&-

    # Dashboard — wait for Gateway to become ready before starting
    if ! pgrep -f "hermes dashboard" > /dev/null; then
        _dashboard_wait=0
        _dashboard_max_wait=10
        until [ "$_dashboard_wait" -ge "$_dashboard_max_wait" ]; do
            if pgrep -f "hermes gateway" > /dev/null; then
                break
            fi
            _dashboard_wait=$(( _dashboard_wait + 1 ))
            sleep 1
        done
        nohup hermes dashboard --no-open > "${HERMES_LOG_DIR}/dashboard.log" 2>&1 &
        log_info "Hermes Dashboard starting on port ${HERMES_DASHBOARD_PORT}."

        # Health-check: wait until Dashboard responds on HTTP
        _hc_retries=0
        _hc_max_retries=60
        until [ "$_hc_retries" -ge "$_hc_max_retries" ]; do
            if curl -fsS "http://127.0.0.1:${HERMES_DASHBOARD_PORT}/" >/dev/null 2>&1; then
                log_info "Hermes Dashboard is responding on port ${HERMES_DASHBOARD_PORT}."
                break
            fi
            _hc_retries=$(( _hc_retries + 1 ))
            sleep 1
        done
        if [ "$_hc_retries" -ge "$_hc_max_retries" ]; then
            log_warn "Hermes Dashboard did not respond within ${_hc_max_retries}s on port ${HERMES_DASHBOARD_PORT}."
        fi
        unset _hc_retries _hc_max_retries
    else
        log_info "Hermes Dashboard already running on port ${HERMES_DASHBOARD_PORT}."
    fi
else
    log_warn "Hermes command not found — skipping Gateway/Dashboard auto-start."
    log_warn "Run 'hermes setup' after installation to enable auto-start."
fi
unset _dashboard_wait _dashboard_max_wait HERMES_DASHBOARD_PORT HERMES_GATEWAY_LOCK_FILE

# ------------------------------------------------------------------
# Hermes config backup on container start
# Runs the backup script and auto-commits any changes to the
# hermes-backup/ directory. This ensures every boot captures the
# latest config state, supplementing the hourly cron backup.
#
# SKIPPED when ~/.hermes/.dr_recovery marker exists (DR recovery mode).
# In recovery mode, the environment is not yet stable — running backup
# would capture incomplete state and commit noise to Git.
# Remove the marker after completing manual setup:
#   rm ~/.hermes/.dr_recovery
# ------------------------------------------------------------------
_HERMES_BACKUP_SCRIPT="/workspaces/hermes-agent-template/.devcontainer/scripts/backup-hermes-config.sh"
_HERMES_BACKUP_DIR="/workspaces/hermes-agent-template/.devcontainer/hermes-backup"

if [ -f "$HOME/.hermes/.dr_recovery" ]; then
    log_warn "DR recovery mode — skipping Hermes config backup."
    log_warn "Complete manual setup (hermes setup, gh auth login, ollama pull), then:"
    log_warn "  rm ~/.hermes/.dr_recovery"
elif [ -f "$_HERMES_BACKUP_SCRIPT" ]; then
    log_info "Running Hermes config backup..."
    if bash "$_HERMES_BACKUP_SCRIPT" 2>&1; then
        # Check for changes and auto-commit if any
        if git -C /workspaces/hermes-agent-template diff --quiet -- "$_HERMES_BACKUP_DIR" 2>/dev/null; then
            log_info "Hermes config backup: no changes detected."
        else
            git -C /workspaces/hermes-agent-template add -- "$_HERMES_BACKUP_DIR"
            git -C /workspaces/hermes-agent-template commit -m "chore: auto-backup hermes config on container start"
            git -C /workspaces/hermes-agent-template push 2>/dev/null || log_warn "Hermes config backup: push failed (offline?)"
            log_info "Hermes config backup: changes committed and pushed."
        fi
    else
        log_warn "Hermes config backup script failed."
    fi
else
    log_warn "Hermes config backup script not found at ${_HERMES_BACKUP_SCRIPT}"
fi
unset _HERMES_BACKUP_SCRIPT _HERMES_BACKUP_DIR

log_info "Post-start setup complete."
