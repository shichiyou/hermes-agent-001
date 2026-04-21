#!/bin/bash
# SPDX-License-Identifier: MIT
# lib.sh — Shared library loader
# ============================================================================
# Sources all shared libraries for use by shell scripts
# ============================================================================

# This file is expected to live in the lib/ directory
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source
# shellcheck source=/dev/null
source "${_LIB_DIR}/logging.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/retry.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/version.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/workspace.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/manifest.sh"

unset _LIB_DIR
