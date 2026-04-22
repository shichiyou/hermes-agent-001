---
name: patch-tool-safety
description: "Safety guidelines for using the patch tool with read_file output. Prevents file corruption from line-number artifacts and git submodule divergence."
version: 1.0.0
metadata:
  hermes:
    tags: [patch, read_file, git, safety, wiki, corruption-prevention]
---

# Patch Tool Safety — File Corruption Prevention

## The Core Danger

`read_file` returns output in `LINE_NUM|CONTENT` format (e.g. `1|# Wiki Index`).
`patch` uses fuzzy matching. If you pass line-numbered text to `old_string`, the line
numbers themselves may be silently stripped — OR may fail to match and fall back to
partial matching that corrupts file structure.

**NEVER pass `read_file` output directly to `patch`'s `old_string`.**

## Rule 1: Strip line numbers before patching

```python
# Safe: get clean content, edit, write
read_file(path="file.md") -> returns line-numbered
# OR: use terminal cat
terminal("cat file.md") -> returns clean, no line numbers
# Then use patch with clean old_string
```

## Rule 2: Wiki file edits MUST use cat or sed, not read_file→patch

For `index.md`, `log.md`, `SCHEMA.md`, or any wiki file:

```bash
# SAFE: Get clean content for patch old_string
head -5 ~/wiki/index.md
# Returns: clean text without "1|" prefixes

# UNSAFE: Don't do this
read_file("~/wiki/index.md")  # Returns: "1|# Wiki Index"
patch(old_string="1|# Wiki Index", ...)  # CORRUPTS file
```

## Rule 3: After patch, always verify with git diff or cat

```bash
git diff -- file.md   # Shows actual changes
head -5 file.md       # Verifies no line-number artifacts
```

## Rule 4: Git submodule safety

When a repository contains git submodules (e.g. `wiki/` pointing to another repo):

1. **Submodules are independent** — `git commit` in the parent does NOT capture
   submodule's new commits. You must also commit inside the submodule directory.
2. **Divergence pattern**: Parent's tracked submodule hash != submodule's HEAD
   → other environments see old submodule state.
3. **Repair**:
   ```bash
   cd ~/wiki && git push   # Push submodule first
   cd /parent-repo && git add wiki && git commit -m "update wiki submodule"
   # Now parent references the pushed hash
   ```
4. **Never force-push overwritten commits to a submodule** if other repos reference
   the old hash. Creates dangling references.

## Rule 5: npx behavior

`npx --yes <package>@<version>` downloads and executes from npm registry
directly — it does NOT require the package to exist in `node_modules` of the
current directory. The install destination (for Playwright: `~/.cache/ms-playwright/`)
is fixed regardless of cwd.

**Consequence**: `cd ~/.hermes/hermes-agent && npx playwright install` is
not required for the install destination, only for package resolution if you don't
use `@version`.
