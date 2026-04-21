#!/bin/bash
# SPDX-License-Identifier: MIT
# ==========================================================================
# on-create.sh — Runs once on first container creation (onCreateCommand)
# Executes after Feature installation so all tool files are present,
# allowing accurate skeleton retrieval
# ==========================================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${SCRIPT_DIR}/scripts/lib"
# shellcheck source=/dev/null
source "${_LIB_DIR}/logging.sh"

log_init "${HOME}/.local/state/on-create.log"
log_info "On-create setup began."

# ------------------------------------------------------------------
# Home volume initialization
# Copies current home contents to an empty volume mount
# Includes any files added by Features (node, python, etc.)
# ------------------------------------------------------------------
if [ ! -f "$HOME/.home_initialized" ]; then
    log_info "Initializing home volume — copying default dotfiles..."
    # /etc/skel からシステムデフォルトをコピー
    cp -a /etc/skel/. "$HOME/" 2>/dev/null || true
    touch "$HOME/.home_initialized"
    log_info "Home volume initialized."
else
    log_info "Home volume already initialized, skipping."
fi

# ------------------------------------------------------------------
# Hermes configuration restore (after home volume initialization)
# Detects empty home volume and restores from Git-managed backup.
#
# DR recovery marker:
# When restoring from backup on a new host, the environment is not yet
# stable (missing API keys, unauthenticated gh, no hub skills, etc.).
# The marker prevents automated backup from running and committing
# unstable state to Git. Remove manually after setup is complete:
#   rm ~/.hermes/.dr_recovery
# ------------------------------------------------------------------
if [ ! -f "$HOME/.hermes/config.yaml" ]; then
    BACKUP_DIR="${SCRIPT_DIR}/hermes-backup"
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Home volume appears empty — restoring Hermes configuration..."
        mkdir -p "$HOME/.hermes"

        # Configuration files
        cp -a "$BACKUP_DIR/config.yaml"  "$HOME/.hermes/" 2>/dev/null || true
        cp -a "$BACKUP_DIR/SOUL.md"       "$HOME/.hermes/" 2>/dev/null || true

        # Memory files
        if [ -d "$BACKUP_DIR/memories" ]; then
            mkdir -p "$HOME/.hermes/memories"
            cp -a "$BACKUP_DIR/memories/" "$HOME/.hermes/" 2>/dev/null || true
        fi

        # Cron jobs
        if [ -d "$BACKUP_DIR/cron" ]; then
            mkdir -p "$HOME/.hermes/cron"
            cp -a "$BACKUP_DIR/cron/" "$HOME/.hermes/" 2>/dev/null || true
        fi

        # Custom skills (non-hub only)
        if [ -d "$BACKUP_DIR/skills" ]; then
            cp -a "$BACKUP_DIR/skills/" "$HOME/.hermes/" 2>/dev/null || true
        fi

        # .bashrc additions (insert before interactive guard)
        if [ -f "$BACKUP_DIR/bashrc-additions.sh" ]; then
            BASHRC="$HOME/.bashrc"
            if ! grep -q "WIKI_PATH" "$BASHRC" 2>/dev/null; then
                # Insert before the interactive guard (# If not running interactively)
                ADDITIONS="$BACKUP_DIR/bashrc-additions.sh"
                if grep -q "^# If not running interactively" "$BASHRC" 2>/dev/null; then
                    sed -i "/^# If not running interactively/e cat \"$ADDITIONS\"" "$BASHRC" 2>/dev/null || \
                    cat "$ADDITIONS" >> "$BASHRC"
                else
                    cat "$ADDITIONS" >> "$BASHRC"
                fi
                log_info ".bashrc additions applied."
            else
                log_info ".bashrc already contains WIKI_PATH, skipping additions."
            fi
        fi

        # .gitconfig template (user identity + gh credential helper)
        if [ -f "$BACKUP_DIR/gitconfig-template" ]; then
            if [ ! -f "$HOME/.gitconfig" ] || ! grep -q "shichiyou" "$HOME/.gitconfig" 2>/dev/null; then
                cat "$BACKUP_DIR/gitconfig-template" >> "$HOME/.gitconfig"
                log_info ".gitconfig template applied."
            fi
        fi

        # Wiki symlink
        if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
            rm "$HOME/wiki"
        fi

        if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ] && [ -d "/workspaces/hermes-agent-template/wiki" ]; then
            ln -s /workspaces/hermes-agent-template/wiki "$HOME/wiki"
            log_info "Wiki symlink created."
        fi

        # .env template (placeholder-ized — user must fill in real secrets)
        if [ -f "$BACKUP_DIR/dot-env-template" ]; then
            if [ ! -f "$HOME/.hermes/.env" ]; then
                cp "$BACKUP_DIR/dot-env-template" "$HOME/.hermes/.env"
                log_info ".env template restored (secrets need manual configuration)."
            else
                log_info ".env already exists, skipping template restore."
            fi
        fi

        log_info "Hermes configuration restored from backup."

        # Set DR recovery marker — backup auto-commit is disabled until
        # the user completes manual setup and removes this file.
        touch "$HOME/.hermes/.dr_recovery"
        log_warn "DR recovery marker created: backup auto-commit is DISABLED."
        log_warn "After completing setup (hermes setup, gh auth login, ollama pull), run:"
        log_warn "  rm ~/.hermes/.dr_recovery"
    else
        log_warn "No backup found in $BACKUP_DIR — skipping restore."
        # Also set DR marker for clean environments
        touch "$HOME/.hermes/.dr_recovery"
        log_warn "DR recovery marker created (no backup available)."
    fi
else
    log_info "Hermes configuration already present, skipping restore."
fi

# ------------------------------------------------------------------
# Hermes Agent installation (for fresh volumes without hermes)
# Uses the GitHub Raw URL to avoid Vercel Bot Challenge (HTTP 429).
# ------------------------------------------------------------------
_HERMES_INSTALL_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

if ! command -v hermes >/dev/null 2>&1; then
    log_info "Hermes Agent not found — installing..."
    _hermes_installed=false
    if curl -fsSL "$_HERMES_INSTALL_URL" | bash; then
        if command -v hermes >/dev/null 2>&1; then
            log_info "Hermes Agent installation complete."
            _hermes_installed=true
        else
            log_warn "Hermes install script exited 0 but 'hermes' command not found."
            log_warn "The installer may have failed silently. Check output above."
        fi
    else
        log_warn "Hermes Agent installation FAILED (installer returned non-zero exit code)."
    fi
    if [ "$_hermes_installed" = true ]; then
        touch "$HOME/.hermes/.dr_recovery"
        log_warn "DR recovery marker created (fresh Hermes install)."
    else
        log_warn "Retry manually after container startup:"
        log_warn "  curl -fsSL $_HERMES_INSTALL_URL | bash"
        touch "$HOME/.hermes/.dr_recovery"
        log_warn "DR recovery marker created (hermes install failed)."
    fi
    unset _hermes_installed
fi
unset _HERMES_INSTALL_URL

# ------------------------------------------------------------------
# Claude Code fallback installation
# The Dockerfile installs Claude Code to /home/vscode/.local/, but this
# directory is overlaid by the home volume mount.  If the volume was
# freshly created (empty), Dockerfile-layer files may be missing.
# This block re-installs Claude Code when the binary is absent.
# ------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
    log_info "Claude Code not found — installing as fallback..."
    _CLAUDE_VERSION="${CLAUDE_CODE_VERSION:-latest}"
    if curl -fsSL https://claude.ai/install.sh | bash -s -- "$_CLAUDE_VERSION"; then
        if command -v claude >/dev/null 2>&1; then
            log_info "Claude Code fallback installation complete."
        else
            log_warn "Claude Code install script exited 0 but 'claude' command not found."
            log_warn "Run 'update-tools.sh claude-code' or rebuild the container."
        fi
    else
        log_warn "Claude Code fallback installation FAILED."
        log_warn "Run 'update-tools.sh claude-code' or rebuild the container."
    fi
    unset _CLAUDE_VERSION
fi

# ------------------------------------------------------------------
# Post-restore reminders (manual steps required)
# ------------------------------------------------------------------
if [ ! -f "$HOME/.hermes/auth.json" ] || [ ! -s "$HOME/.hermes/auth.json" ]; then
    log_warn "=== ACTION REQUIRED ==="
    log_warn "Hermes auth.json is missing or empty."
    log_warn "Run 'hermes setup' after container startup to configure API keys."
    log_warn "======================="
fi

if ! gh auth status >/dev/null 2>&1; then
    log_warn "=== ACTION REQUIRED ==="
    log_warn "GitHub CLI is not authenticated."
    log_warn "Run 'gh auth login' to enable Git push to private repositories."
    log_warn "======================="
fi

# Warn if .env contains commented-out credential lines (need manual setup)
# Previously, placeholders like YOUR_*_HERE were used, but Hermes treats ANY
# non-empty value as "already configured" and skips key entry, causing 401 errors.
# The new format comments out sensitive lines: "# OLLAMA_API_KEY=  # Set via ..."
if [ -f "$HOME/.hermes/.env" ]; then
    COMMENTED_SECRETS=$(grep -cE '^#\s*[A-Z_]+_(TOKEN|KEY|SECRET|PASSWORD|API_KEY|ALLOWED_USERS|HOME_CHANNEL)=' "$HOME/.hermes/.env" 2>/dev/null || true)
    # Legacy: also check for old-style YOUR_*_HERE placeholders
    PLACEHOLDER_COUNT=$(grep -c 'YOUR_.*_HERE' "$HOME/.hermes/.env" 2>/dev/null || true)
    TOTAL=$((COMMENTED_SECRETS + PLACEHOLDER_COUNT))
    if [ "$TOTAL" -gt 0 ]; then
        log_warn "=== ACTION REQUIRED ==="
        if [ "$COMMENTED_SECRETS" -gt 0 ]; then
            log_warn ".env has ${COMMENTED_SECRETS} commented-out credential(s) that need setup."
            log_warn "Run 'hermes auth add <provider> --type api-key' or 'hermes setup model' to configure."
        fi
        if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
            log_warn ".env has ${PLACEHOLDER_COUNT} old-style placeholder(s) (YOUR_*_HERE)."
            log_warn "These MUST be replaced — Hermes treats them as real keys and will cause 401 errors."
            log_warn "Either fill in real values or comment out the lines."
        fi
        log_warn "Without real credentials, provider authentication will fail with HTTP 401."
        log_warn "======================="
    fi
fi

log_info "On-create setup complete."
