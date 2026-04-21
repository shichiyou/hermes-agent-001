#!/bin/bash
# SPDX-License-Identifier: MIT
# retry.sh — Retry utility library
# ============================================================================
# Provides command retry with exponential backoff support
# ============================================================================

# Defaults
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_INTERVAL="${RETRY_INTERVAL:-1}"
RETRY_BACKOFF_MULTIPLIER="${RETRY_BACKOFF_MULTIPLIER:-2}"
RETRY_MAX_INTERVAL="${RETRY_MAX_INTERVAL:-30}"

# Simple retry wrapper
# Usage: retry 3 my_command arg1 arg2
retry() {
    local retry_max_attempts="${1:-$RETRY_ATTEMPTS}"
    shift

    local retry_current_attempt=1
    until "$@"; do
        if [ "$retry_current_attempt" -ge "$retry_max_attempts" ]; then
            echo "Command failed after $retry_current_attempt attempts: $*" >&2
            return 1
        fi

        echo "Retrying ($((retry_current_attempt + 1))/${retry_max_attempts}): $*" >&2
        retry_current_attempt=$((retry_current_attempt + 1))
        sleep "$RETRY_INTERVAL"
    done
}

# Retry with exponential backoff
# Usage: retry_with_backoff 3 1 my_command arg1 arg2
# Args: attempts base_interval command args...
retry_with_backoff() {
    local retry_max_attempts="${1:-$RETRY_ATTEMPTS}"
    local retry_base_interval="${2:-$RETRY_INTERVAL}"
    shift 2

    local retry_current_attempt=1
    local retry_current_interval="$retry_base_interval"

    until "$@"; do
        if [ "$retry_current_attempt" -ge "$retry_max_attempts" ]; then
            echo "Command failed after $retry_current_attempt attempts: $*" >&2
            return 1
        fi

        echo "Retrying ($((retry_current_attempt + 1))/${retry_max_attempts}) in ${retry_current_interval}s: $*" >&2
        retry_current_attempt=$((retry_current_attempt + 1))

        sleep "$retry_current_interval"

        # Exponentially increase the interval, capped at the maximum
        retry_current_interval=$((retry_current_interval * RETRY_BACKOFF_MULTIPLIER))
        if [ "$retry_current_interval" -gt "$RETRY_MAX_INTERVAL" ]; then
            retry_current_interval="$RETRY_MAX_INTERVAL"
        fi
    done
}
