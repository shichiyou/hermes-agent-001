# Editor / Extension Config Triangulation

Use this when a VS Code / editor extension setting appears to be ignored and you must distinguish:
1. invalid local config syntax
2. editor scope limitation
3. extension bug / implementation gap
4. known upstream limitation with workaround

## Verification Ladder

1. Confirm the local config file physically contains the setting.
   - Example: read the `.code-workspace`, `.vscode/settings.json`, or user settings file.
2. Check editor official docs for the claimed syntax/scope.
   - Do not assume undocumented JSON shapes are supported.
3. Check editor issues/discussions for explicit support gaps.
   - Feature-request issues are strong evidence that the syntax is not supported.
4. Inspect the extension manifest (`package.json`) for the setting declaration.
   - Check `scope` (`application`, `machine`, `window`, `resource`, etc.).
5. Inspect extension runtime code to see how the setting is read.
   - Example: whether it calls `getConfiguration(..., workspaceFolder)` or only reads global/workspace scope.
6. Search extension issues for matching symptoms and maintainer workarounds.

## VS Code × Biome Example (2026-05)

### Local file observed
A multi-root `.code-workspace` used keys such as:

```json
"settings": {
  "[/home/vscode]": {
    "biome.enabled": false
  }
}
```

### VS Code official docs observed
- `[]` syntax is documented for language-specific settings such as `[typescript]` and `[markdown]`.
- Multi-root docs describe `individual folder settings` and `Preferences: Open Folder Settings`.
- No official documentation was found for path-based folder targeting inside `.code-workspace` settings via `[path]`.

### VS Code issue evidence
Issue `microsoft/vscode#301590` states:
- per-workspace-folder settings are supported with `.vscode/settings.json`
- putting folder settings directly in `.code-workspace` is a feature request

This is strong evidence that `[path]` inside `.code-workspace` is not a supported folder-settings syntax.

### Biome extension manifest observed
`biome.enabled` is declared with:

```json
"scope": "resource"
```

Meaning: the setting can apply per resource / workspace folder if the editor actually provides that scope.

### Biome runtime observed
The extension reads enabled state with workspace-folder scope:

```js
config("enabled", { scope: this.workspaceFolder, default: true })
```

Meaning: Biome does support folder-scoped disable/enable, but via supported VS Code configuration scopes.

### Resulting conclusion
If `"[/home/vscode]": { "biome.enabled": false }` does not work, the primary cause is likely not Biome ignoring `biome.enabled`, but VS Code not treating `[path]` as valid folder-settings syntax in `.code-workspace`.

### Workarounds found in Biome issues
Maintainer/user guidance in `biomejs/biome-vscode` issues indicates practical workarounds:

1. Disable Biome at workspace level in `.code-workspace`

```json
{
  "settings": {
    "biome.enabled": false
  }
}
```

2. Re-enable only in selected folders via each folder's `.vscode/settings.json`

```json
{
  "biome.enabled": true
}
```

3. In nested-workspace scenarios, disable Biome in the root folder's `.vscode/settings.json` to prevent overlapping LSP instances.

## Pitfalls
- Do not treat “JSON key exists” as proof the editor supports that syntax.
- Do not stop at docs alone when extension runtime behavior matters.
- Do not blame the extension before checking whether the host editor ever delivers the intended scope.
- For editor integrations, maintainer comments in issues often contain the only documented workaround.
