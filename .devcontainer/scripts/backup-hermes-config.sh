#!/bin/bash
# SPDX-License-Identifier: MIT
# ==========================================================================
# backup-hermes-config.sh — Sync Hermes configuration to Git-managed backup
#
# Usage:
#   bash .devcontainer/scripts/backup-hermes-config.sh
#
# This script copies Hermes Agent configuration files from the home volume
# into the .devcontainer/hermes-backup/ directory for version control.
# Run this after making configuration changes (cron jobs, skills, etc.)
# and commit the result.
#
# Note: auth.json is intentionally excluded (contains API keys).
#       Run 'hermes setup' on a new host to re-configure credentials.
#
# DR recovery guard:
# If ~/.hermes/.dr_recovery exists, this script exits immediately.
# The marker indicates an unstable environment (fresh restore or install)
# where backup would capture incomplete state. Remove after setup:
#   rm ~/.hermes/.dr_recovery
# ==========================================================================
set -euo pipefail

# ── DR recovery guard ─────────────────────────────────────────────
if [ -f "${HERMES_HOME:-$HOME/.hermes}/.dr_recovery" ]; then
    echo "DR recovery mode detected (.dr_recovery marker exists)."
    echo "Skipping backup — environment is not yet stable."
    echo "Complete manual setup, then: rm ~/.hermes/.dr_recovery"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../hermes-backup"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

echo "=== Hermes Configuration Backup ==="
echo "Source: ${HERMES_HOME}"
echo "Target: ${BACKUP_DIR}"
echo ""

# ── Pre-flight checks ──────────────────────────────────────────────
if [ ! -d "${HERMES_HOME}" ]; then
    echo "ERROR: ${HERMES_HOME} does not exist. Is Hermes installed?" >&2
    exit 1
fi

if [ ! -f "${HERMES_HOME}/config.yaml" ]; then
    echo "ERROR: ${HERMES_HOME}/config.yaml not found." >&2
    exit 1
fi

# ── Create backup directory structure ────────────────────────────────
mkdir -p "${BACKUP_DIR}"/{memories,cron}

# ── Configuration files ─────────────────────────────────────────────
echo "Syncing configuration files..."
cp -a "${HERMES_HOME}/config.yaml"  "${BACKUP_DIR}/"
cp -a "${HERMES_HOME}/SOUL.md"      "${BACKUP_DIR}/" 2>/dev/null || echo "  (SOUL.md not found, skipping)"

# ── Memory files ─────────────────────────────────────────────────────
echo "Syncing memory files..."
cp -a "${HERMES_HOME}/memories/MEMORY.md" "${BACKUP_DIR}/memories/" 2>/dev/null || echo "  (MEMORY.md not found, skipping)"
cp -a "${HERMES_HOME}/memories/USER.md"    "${BACKUP_DIR}/memories/" 2>/dev/null || echo "  (USER.md not found, skipping)"

# ── Cron jobs ────────────────────────────────────────────────────────
echo "Syncing cron jobs..."
cp -a "${HERMES_HOME}/cron/jobs.json" "${BACKUP_DIR}/cron/" 2>/dev/null || echo "  (jobs.json not found, skipping)"

# ── Custom skills (non-hub, non-bundled only) ────────────────────────
echo "Syncing custom skills..."
SKILLS_DIR="${HERMES_HOME}/skills"
BUNDLED_MANIFEST="${HERMES_HOME}/skills/.bundled_manifest"
copied_count=0

# is_bundled: Check if a skill directory is a bundled skill.
# Primary check: read the "name:" field from SKILL.md and match against
# bundled_manifest. This handles cases where directory names differ from
# manifest keys (e.g., directory "gguf" → manifest key "gguf-quantization").
# Fallback: basename match for skills without a SKILL.md name field.
is_bundled() {
    local skill_dir="$1"

    # Primary: match SKILL.md name: field against manifest
    if [ -f "${skill_dir}/SKILL.md" ] && [ -f "${BUNDLED_MANIFEST}" ]; then
        local skill_name
        skill_name="$(grep -m1 '^name:' "${skill_dir}/SKILL.md" 2>/dev/null | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')"
        if [ -n "${skill_name}" ]; then
            if grep -q "^${skill_name}:" "${BUNDLED_MANIFEST}" 2>/dev/null; then
                return 0
            fi
        fi
    fi

    # Fallback: basename match (covers older or unusual skills)
    local basename
    basename="$(basename "${skill_dir}")"
    if [ -f "${BUNDLED_MANIFEST}" ] && grep -q "^${basename}:" "${BUNDLED_MANIFEST}" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Use find to discover ALL skill directories (any depth), then filter.
# This fixes the bug where 3-level nested skills (mlops/inference/gguf)
# were missed by the old glob-based loops.
while IFS= read -r skill_dir; do
    # Skip hub-installed skills (identified by .hub_install marker)
    if [ -f "${skill_dir}/.hub_install" ]; then
        continue
    fi

    # Skip bundled skills (check against bundled manifest)
    if is_bundled "${skill_dir}"; then
        continue
    fi

    # Compute relative path (e.g., "devops/hermes-cron-ops")
    skill_rel="${skill_dir#${SKILLS_DIR}/}"

    target="${BACKUP_DIR}/skills/${skill_rel}"
    mkdir -p "${target}"
    cp -a "${skill_dir}"/* "${target}/"
    echo "  Synced: ${skill_rel}"
    copied_count=$(( copied_count + 1 ))
done < <(find "${SKILLS_DIR}" -name SKILL.md -type f -exec dirname {} \; | sort -u)

echo "  Total custom skills synced: ${copied_count}"

# ── Prune stale skill backups ────────────────────────────────────────
# Remove backup directories for skills that are no longer custom
# (e.g., re-installed as hub/bundled skills since the last backup).
BACKUP_SKILLS_DIR="${BACKUP_DIR}/skills"
if [ -d "${BACKUP_SKILLS_DIR}" ]; then
    pruned_count=0
    while IFS= read -r backup_skill_dir; do
        backup_rel="${backup_skill_dir#${BACKUP_SKILLS_DIR}/}"
        # Check if this skill still exists as custom in the source
        source_skill="${SKILLS_DIR}/${backup_rel}"
        if [ ! -d "${source_skill}" ]; then
            # Source directory removed entirely — prune backup
            echo "  Pruned (source removed): ${backup_rel}"
            rm -rf "${backup_skill_dir}"
            pruned_count=$(( pruned_count + 1 ))
            continue
        fi
        # Source exists — check if it is still custom (not hub/bundled)
        if [ -f "${source_skill}/.hub_install" ] || is_bundled "${source_skill}"; then
            echo "  Pruned (now hub/bundled): ${backup_rel}"
            rm -rf "${backup_skill_dir}"
            pruned_count=$(( pruned_count + 1 ))
        fi
    done < <(find "${BACKUP_SKILLS_DIR}" -name SKILL.md -type f -exec dirname {} \; | sort -u)
    # Clean up empty parent directories left after pruning
    find "${BACKUP_SKILLS_DIR}" -type d -empty -delete 2>/dev/null || true
    if [ "${pruned_count}" -gt 0 ]; then
        echo "  Total skills pruned: ${pruned_count}"
    fi
fi

# ── .bashrc additions ───────────────────────────────────────────────
echo "Generating .bashrc additions template..."
cat > "${BACKUP_DIR}/bashrc-additions.sh" <<'HERMES_BASHRC'
# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-001/wiki"

# Wiki symlink (for convenience)
if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
    rm "$HOME/wiki"
fi

if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ]; then
    ln -s /workspaces/hermes-agent-001/wiki "$HOME/wiki"
fi
HERMES_BASHRC

# ── .gitconfig template ─────────────────────────────────────────────
echo "Generating .gitconfig template..."
cat > "${BACKUP_DIR}/gitconfig-template" <<'GITCONFIG'
[user]
	name = Tanaka Yasunobu
	email = shichiyou@outlook.com

[credential "https://github.com"]
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper = !/usr/bin/gh auth git-credential
GITCONFIG

# ── .env template (sensitive values redacted) ──────────────────────
echo "Generating .env template (sensitive values redacted)..."
if [ -f "${HERMES_HOME}/.env" ]; then
    DOTENV_TEMPLATE="${BACKUP_DIR}/dot-env-template"
    : > "${DOTENV_TEMPLATE}"  # truncate/create empty file

    # Sensitive variable patterns:
    # - _TOKEN, _KEY, _SECRET, _PASSWORD suffixes → credential values
    # - *_ALLOWED_USERS, *_HOME_CHANNEL, *_HOME_CHANNEL_NAME → instance-specific config
    #   (keeping real values would enable parallel Discord connections on clone)
    # - Long opaque strings (heuristic) → likely credentials
    while IFS= read -r line; do
        # Skip empty lines and comments — preserve as-is
        if [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]]; then
            echo "${line}" >> "${DOTENV_TEMPLATE}"
            continue
        fi

        # Extract variable name and value
        var_name="${line%%=*}"
        var_value="${line#*=}"

        # Skip lines without '=' (malformed)
        if [[ "${line}" != *"="* ]]; then
            echo "${line}" >> "${DOTENV_TEMPLATE}"
            continue
        fi

        # Check if this is a sensitive variable
        # Category 1: Credential suffixes (_TOKEN, _KEY, _SECRET, _PASSWORD)
        # Category 2: Instance-specific identifiers (ALLOWED_USERS, HOME_CHANNEL)
        #   These enable a Discord bot connection — keeping real values in Git
        #   would allow parallel instances to fight over the same bot token.
        # Category 3: Long opaque strings (heuristic for credentials)
        #
        # IMPORTANT: Sensitive variables are COMMENTED OUT (not just placeholder-ized).
        # Hermes setup reads .env and treats any non-empty value as "already configured",
        # skipping key entry. Writing OLLAMA_API_KEY=YOUR_OLLAMA_API_KEY_HERE causes
        # hermes setup to skip API key setup, resulting in 401 errors at runtime.
        # Commented-out lines like "# OLLAMA_API_KEY=" are correctly ignored by Hermes.
        if [[ "${var_name}" == *"_TOKEN" ]] || \
           [[ "${var_name}" == *"_KEY" ]] || \
           [[ "${var_name}" == *"_SECRET" ]] || \
           [[ "${var_name}" == *"_PASSWORD" ]] || \
           [[ "${var_name}" == *"API_KEY"* ]] || \
           [[ "${var_name}" == *"ALLOWED_USERS" ]] || \
           [[ "${var_name}" == *"HOME_CHANNEL" ]]; then
            # Redact: comment out and show variable name as hint
            printf '# %s=  # Set via hermes auth add or hermes setup\n' "${var_name}" >> "${DOTENV_TEMPLATE}"
        elif [[ -n "${var_value}" && "${#var_value}" -gt 20 ]] && \
             [[ "${var_value}" =~ ^[A-Za-z0-9+/=_-]+$ ]]; then
            # Heuristic: long opaque strings are likely credentials
            printf '# %s=  # Set via hermes auth add or hermes setup\n' "${var_name}" >> "${DOTENV_TEMPLATE}"
        else
            # Non-sensitive: preserve actual value (e.g., HERMES_MAX_ITERATIONS=60)
            echo "${line}" >> "${DOTENV_TEMPLATE}"
        fi
    done < "${HERMES_HOME}/.env"
    echo "  .env template generated with sensitive values redacted."
else
    echo "  (.env not found, skipping)"
fi

# ── Ollama models list ──────────────────────────────────────────────
echo "Generating Ollama models list..."
OLLAMA_MODELS="${BACKUP_DIR}/ollama-models.txt"
cat > "${OLLAMA_MODELS}" <<'OLLAMA_HEADER'
# Ollama models required by Hermes Agent
# Install with: ollama pull <model>
OLLAMA_HEADER
if command -v ollama >/dev/null 2>&1; then
    ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' >> "${OLLAMA_MODELS}" || echo "  (ollama list failed)"
else
    echo "# (ollama command not available, models not listed)" >> "${OLLAMA_MODELS}"
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "=== Backup complete ==="
echo "Files are in: ${BACKUP_DIR}"
echo ""
echo "To review changes:"
echo "  git diff .devcontainer/hermes-backup/"
echo ""
echo "To commit:"
echo "  git add .devcontainer/hermes-backup/"
echo "  git commit -m 'update hermes backup'"
