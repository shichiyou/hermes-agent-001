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

Observed example:

```text
.devcontainer/hermes-backup/cron/jobs.json | 8 ++++----
1 file changed, 4 insertions(+), 4 deletions(-)
```

## Common Legitimate Delta
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
Two easy failure modes are:
- hardcoding the wrong workspace path in a container fleet where the suffix changes
- treating `cron/jobs.json` timestamp/state updates as ignorable and skipping the repository-backed backup policy

This protocol avoids both.