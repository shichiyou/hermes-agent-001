# Agent Instructions Coverage Audit: Graphify & CoDD in AI Agent Configs

Original finding: 2026-05-01 | Fix implemented: 2026-05-01
Repository: `experiences/aidlc-codd-graphify-lab`

## Original Finding (pre-fix)

AIエージェント指示ファイルに、GraphifyとCoDDの役割や意味の説明が含まれていなかった。実行コマンドのみが断片的に記載され、`.github/copilot-instructions.md` では Build and Test ゲート全体と Graphify/CoDD の言及がゼロ件だった。

### Pre-fix State

| File | Lines | Graphify refs | CoDD refs | Tool role definitions |
|---|---|---|---|---|
| AGENTS.md | 646 | 4 | 2 | ❌ None |
| CLAUDE.md | 646 | 4 | 2 | ❌ None |
| .github/copilot-instructions.md | 627 | 0 | 0 | ❌ None |

Critical gap: `v-model-development-process.md` defined Graphify as "NOT a pass/fail gate" but AGENTS.md put `graphify update` inside "EXECUTE deterministic gates".

## Fix Implemented (2026-05-01)

4 changes applied to all 3 files:

### Change 1: Tool Role Definition Section (LAB-SPECIFIC zone)

Added `## ツールの役割と使用方法（ラボ固有）` section with:
- Role table (AI-DLC / CoDD / pytest / Graphify with gate decision semantics)
- CoDD frontmatter required fields (7 fields)
- CoDD commands and judgment criteria (4 commands)
- Graphify commands and usage (4 commands)
- Graphify output artifacts and handling (3 artifacts)
- Graphify CI pass/fail semantics (3 checks)
- Three-Way Coherence Closure standard cycle with role per command

### Change 2: Build and Test Gate Reclassification

`graphify update sample-app` moved from "EXECUTE deterministic gates" to new step 4:
```
4. **EXECUTE structural verification** (supplementary — NOT a pass/fail gate):
```
- Deterministic gates (pytest, codd, traceability): FAIL → block
- Structural verification (graphify, coverage check): FAIL → report, continue
- INFERRED edges explicitly documented as NOT pass/fail criteria

### Change 3: Code Generation Verification Fix

`codd validate && codd scan` added fail handling:
```markdown
- IF FAIL: report in audit.md; fix frontmatter or source references before continuing
- IF PASS: record coherence state in audit.md
```

### Change 4: copilot-instructions.md Gap Fill

Restored missing sections:
- Code Generation post-generation verification (+8 lines)
- Build and Test deterministic gates + structural verification (+19 lines)
- Tool role definition section (+90 lines)

### Post-fix Verification

| Check | Result |
|---|---|
| 3 files all 747 lines | ✅ |
| AGENTS.md == CLAUDE.md (diff 0) | ✅ |
| Graphify mentions per file | 22 |
| CoDD mentions per file | 13 |
| INFERRED warning (lines 472, 677) | ✅ All 3 files |
| deterministic/structural distinction (lines 453, 465) | ✅ All 3 files |
| v-model-development-process.md role table alignment | ✅ |
| Git push | aidlc-codd-graphify-lab `95d4c30`, parent `ae49847` |

## Remaining Gap

`.aidlc-rule-details/` (29 files) has zero references to Graphify or CoDD. This is **intentional**: AI-DLC official rule details are upstream-managed. Tool awareness belongs in the LAB-SPECIFIC section of agent instruction files, which is where it now resides.

## Re-application Checklist

When applying this fix to a new project or after an AI-DLC update overwrites agent files:

1. Re-add the `## ツールの役割と使用方法（ラボ固有）` section in the LAB-SPECIFIC zone
2. Reclassify Graphify from deterministic gates to structural verification
3. Add codd FAIL handling in Code Generation verification
4. Ensure copilot-instructions.md has parity with AGENTS.md for all gate sections
5. Verify: `grep -c 'graphify\|Graphify' AGENTS.md CLAUDE.md .github/copilot-instructions.md` returns equal counts
6. Verify: `grep -c 'codd\|CoDD' AGENTS.md CLAUDE.md .github/copilot-instructions.md` returns equal counts