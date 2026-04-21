#!/bin/bash
# SPDX-License-Identifier: MIT
# logging.sh — Unified logging library
# ============================================================================
# Provides log level definitions, formatted output, and file output
# ============================================================================

# Log level definitions
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Internal variables
_LOG_FILE="${LOG_FILE:-}"
_LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Returns the log level name for a given level constant
_log_level_name() {
    case "$1" in
        "$LOG_LEVEL_DEBUG") printf '%s\n' "DEBUG" ;;
        "$LOG_LEVEL_INFO")  printf '%s\n' "INFO" ;;
        "$LOG_LEVEL_WARN")  printf '%s\n' "WARN" ;;
        "$LOG_LEVEL_ERROR") printf '%s\n' "ERROR" ;;
        *)                   printf '%s\n' "UNKNOWN" ;;
    esac
}

# Gets the current timestamp
_log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Internal log writer
_log_write() {
    local level="$1"
    local message="$2"
    local level_name
    local timestamp

    level_name="$(_log_level_name "$level")"
    timestamp="$(_log_timestamp)"

    local output="[${timestamp}] [${level_name}] ${message}"

    # Print to stdout
    printf '%s\n' "$output"

    # Write to file (if configured)
    if [ -n "$_LOG_FILE" ]; then
        printf '%s\n' "$output" >> "$_LOG_FILE"
    fi
}

# Sets the log file path
log_init() {
    _LOG_FILE="${1:-}"
    if [ -n "$_LOG_FILE" ]; then
        local dir
        dir="$(dirname "$_LOG_FILE")"
        mkdir -p "$dir"
    fi
}

# Sets the current log level
log_set_level() {
    case "$1" in
        debug) _LOG_LEVEL="$LOG_LEVEL_DEBUG" ;;
        info)  _LOG_LEVEL="$LOG_LEVEL_INFO" ;;
        warn)  _LOG_LEVEL="$LOG_LEVEL_WARN" ;;
        error) _LOG_LEVEL="$LOG_LEVEL_ERROR" ;;
        *)
            echo "Unknown log level: $1" >&2
            return 1
            ;;
    esac
}

# Logs a debug-level message
log_debug() {
    if [ "$_LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]; then
        _log_write "$LOG_LEVEL_DEBUG" "$*"
    fi
}

# Logs an info-level message
log_info() {
    if [ "$_LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]; then
        _log_write "$LOG_LEVEL_INFO" "$*"
    fi
}

# Logs a warning-level message
log_warn() {
    if [ "$_LOG_LEVEL" -le "$LOG_LEVEL_WARN" ]; then
        _log_write "$LOG_LEVEL_WARN" "$*"
    fi
}

# Logs an error-level message
log_error() {
    if [ "$_LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]; then
        _log_write "$LOG_LEVEL_ERROR" "$*"
    fi
}
