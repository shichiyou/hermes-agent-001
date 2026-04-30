# Biome "undefined" Status Bar — Root Cause Analysis

## Symptom
VS Code status bar shows `$(biome-logo) undefined` instead of `$(biome-logo) 2.4.13`.

## Root Cause
The `.code-workspace` file defined 5 workspace folders:
1. `.` (project root — has `biome.json` + `node_modules/@biomejs/cli-*`)
2. `experiences/aidlc-codd-graphify-lab` (no biome.json, no node_modules)
3. `experiences/promptfoo-ci-lab` (no biome.json, no node_modules)
4. `wiki` (no biome.json, no node_modules)
5. `/home/vscode` (no biome.json, no node_modules)

The Biome extension (v3.6.1) creates one LSP instance per workspace folder in multi-root mode. Folders 2-5 have no local `@biomejs/cli-*` binary. For folder 5 (`/home/vscode`), even `findBiomeInPath()` fails, so no binary is resolved and the LSP session never initializes. The extension reads `initializeResult.serverInfo.version` → `undefined`, and the status bar template `` `$(biome-logo) ${version}` `` renders "undefined".

Additionally, folders 2-4 overlap with the project root (they are subdirectories), causing:
- Duplicate file processing by multiple Biome instances
- Spam: "configuration file found outside of the current working directory" per file event
- "Overlapping workspace roots" warnings in `Biome.log`

## Diagnostic Commands
```bash
# Check extension logs
cat ~/.vscode-server/data/logs/*/exthost1/biomejs.biome/Biome.log | tail -30

# Check per-folder LSP logs for config warnings
cat ~/.vscode-server/data/logs/*/exthost1/biomejs.biome/Biome\ \(*\)\ -\ LSP.log | tail -20

# Verify binary resolution per folder
for d in "." "experiences/aidlc-codd-graphify-lab" "experiences/promptfoo-ci-lab" "wiki"; do
  echo "=== $d ==="
  ls "$d/biome.json" 2>/dev/null || echo "  No biome.json"
  ls "$d/node_modules/.bin/biome" 2>/dev/null || echo "  No local biome binary"
done

# Check status bar text source (extension source)
grep -n 'statusBarItem\.text' ~/.vscode-server/extensions/biomejs.biome-*/out/main.js
# Key line: `$(biome-logo) ${(_b = this.extension.biome) == null ? void 0 : _b.version}`
```

## Fix
Reduce `.code-workspace` to single folder:
```json
{
  "folders": [{ "name": "プロジェクトルート", "path": "." }],
  "settings": { ... }
}
```

Commit: `cae2fad` — "fix: consolidate workspace to single root — eliminate overlapping Biome instances and undefined status bar"

## Key Source Code Context (biomejs.biome v3.6.1)
- L23107: `this.statusBarItem.text = \`$(biome-logo) ${(_b = this.extension.biome) == null ? void 0 : _b.version}\``
- L22748: `get version() { return (_a = this._session) == null ? void 0 : _a.biomeVersion; }`
- L22513: `get biomeVersion() { return (_c = (_b = (_a = this.client) == null ? void 0 : _a.initializeResult) == null ? void 0 : _b.serverInfo) == null ? void 0 : _c.version; }`

When `initializeResult.serverInfo` is absent (binary not found / LSP not started), `biomeVersion` returns `undefined`.