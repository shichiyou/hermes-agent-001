# Hourly Hermes Config Backup Protocol

Use this reference when a scheduled job backs up Hermes configuration into the repository and may need to commit/push changes.

## Discovery
Do not assume the workspace root name. Find the script dynamically:

```bash
find /workspaces -name "backup-hermes-config.sh" -path "*/hermes-agent*"
```

Interpretation rule:
- The workspace root is the directory that contains `.devcontainer/scripts/backup-hermes-config.sh`.

Example observed path:
- `/workspaces/hermes-agent-001/.devcontainer/scripts/backup-hermes-config.sh`

Therefore workspace root:
- `/workspaces/hermes-agent-001`

## Execution
Run the backup from the discovered root:

```bash
cd <WORKSPACE_ROOT> && bash .devcontainer/scripts/backup-hermes-config.sh
```

If your terminal wrapper supports a dedicated working-directory parameter, prefer setting that to `<WORKSPACE_ROOT>` and invoking:

```bash
bash .devcontainer/scripts/backup-hermes-config.sh
```

This avoids shell-wrapper quirks around `bash -lc` / `sh -c` approval rules while preserving the same effect.

Expected output includes:
- `=== Hermes Configuration Backup ===`
- `Syncing configuration files...`
- `Syncing memory files...`
- `Syncing cron jobs...`
- `Syncing custom skills...`
- `=== Backup complete ===`

## Diff Check
Check only the backup directory:

```bash
cd <WORKSPACE_ROOT> && git diff --stat .devcontainer/hermes-backup/
```

If output is empty: stop, no commit.

If output is non-empty: continue.

Observed examples:

```text
.devcontainer/hermes-backup/cron/jobs.json                                          | 8 ++++----
1 file changed, 4 insertions(+), 4 deletions(-)
```

```text
.devcontainer/hermes-backup/cron/jobs.json                                          | 8 ++++----
.devcontainer/hermes-backup/skills/devops/hermes-infrastructure-operations/SKILL.md | 1 +
2 files changed, 5 insertions(+), 4 deletions(-)
```

## Common Legitimate Deltas
A normal hourly run may update only:
- `.devcontainer/hermes-backup/cron/jobs.json`

Observed fields that advanced during a legitimate run:
- `repeat.completed`
- `next_run_at`
- `last_run_at`
- top-level `updated_at`

Example pattern:
- `repeat.completed: 180 -> 181`
- `next_run_at: 2026-05-02T09:00:00+00:00 -> 2026-05-02T10:00:00+00:00`
- `last_run_at: 2026-05-02T07:00:15... -> 2026-05-02T08:01:07...`

Another legitimate run may also include mirrored custom-skill changes under:
- `.devcontainer/hermes-backup/skills/...`

Treat these as ordinary backup content, not as a reason to narrow the staging path further than `.devcontainer/hermes-backup/`.

## Commit Sequence
```bash
git add .devcontainer/hermes-backup/
git diff --cached --name-status
git commit -m "chore: automated hourly hermes config backup"
git log --oneline -1
git push
git status --short --branch
git rev-parse HEAD && git rev-parse origin/main
```

## Verification Criteria
Treat the run as complete only when all are true:
1. Backup script exited 0.
2. `git diff --stat .devcontainer/hermes-backup/` was evaluated.
3. If there were changes, `git diff --cached --name-status` showed the staged backup files.
4. `git log --oneline -1` shows the new backup commit.
5. `git push` succeeded.
6. `git status --short --branch` shows no remaining working-tree changes.
7. `git rev-parse HEAD` equals `git rev-parse origin/main`.

## Why this matters
Three easy failure modes are:
- hardcoding the wrong workspace path in a container fleet where the suffix changes
- treating `cron/jobs.json` timestamp/state updates as ignorable and skipping the repository-backed backup policy
- assuming hourly deltas are always single-file changes and overlooking mirrored custom-skill updates inside the backup tree

This protocol avoids all three.