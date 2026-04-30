# Assumption Surfacing — Evolution Log

## v1.0.0 (2026-04-30): Initial creation

### Origin

Cole Medin's "Principles of Agentic Engineering" workshop (2026-04-28) proposed 5 Golden Rules. Rule #2: **Reduce assumptions** — ask before PRD, review before Jira, plan before implement.

### First implementation: `describe-clarify`

Initially implemented as `describe-clarify` (software-development category) — a scoped skill for the DESCRIBE → CLARIFY pattern in greenfield development. Covered:
- DESCRIBE: brain-dump of what to build
- CLARIFY: agent asks questions to surface assumptions
- 6 question categories, 4 answer rules

### User correction → rename + scope expansion

User observation: "It's not just about building something. Even for any task, if you propose your interpretation or ask questions instead of silently inferring, rework decreases."

Key insight: The "Reduce assumptions" principle is not specific to greenfield development. It applies to ALL task types: bug fixes, refactoring, documentation, wiki updates, configuration changes.

**Decision**: Rename to `assumption-surfacing` (前提の顕在化) and elevate to a basic behavioral principle with `always_load: true`.

### Structural changes from describe-clarify → assumption-surfacing

- **Core principle** extracted: "Never silently infer — propose interpretation or ask" (applicable universally)
- **DESCRIBE → CLARIFY** retained as a specialized expansion pattern (new development only), not the main content
- **Application scope table** added (6 task types beyond greenfield)
- **Self-check before execution** added (3 questions)
- **Anti-patterns** expanded from 4 to 7
- **Relationship to existing skills** added (ai-agent-conduct, thinking-framework, plan/writing-plans)

### ai-agent-conduct integration

Added "Assumption Surfacing (mandatory for ambiguous requirements)" paragraph to ai-agent-conduct Principle 2, bridging the gap between:
- ai-agent-conduct: "Stop if HOW (implementation method) is unknown"
- assumption-surfacing: "Stop if WHAT (requirement itself) is ambiguous"

Also added `assumption-surfacing` to `related_skills` in ai-agent-conduct frontmatter.

### v1.1.0 (2026-04-30): EPT-driven improvement

Empirical Prompt Tuning evaluation with 3 scenarios × 3 iterations. 8 Failure Patterns identified and resolved:

**Iteration 1→2 (P1+P2: 核心概念 + パターン選択)**:
- Added ambiguity 3-type classification (語句の多義性, スコープ欠落, 優先度・制約の未指定)
- Added pattern selection order (1→2 evaluate; 3 on explicit delegation only) and combinability rule
- Explicit threshold: Pattern 1 = ≤2 interpretations, Pattern 2 = ≥3 (with boundary handling)
- Added self-check timing rule (task start + each sub-task start)
- Added question category priority (1-6) and per-round density guide (3-5 items)
- Added rework coefficient heuristic table
- Added Pattern 3 rationale requirement (1+ alternative comparison or constraint rationale)
- Added emergency inference permission format with assumption list + confidence labels
- Added escape clause default behavior ("no-pattern-fits state does not exist")
- Added EPT cross-reference for external verification

**Iteration 2→3 (P1残+P3残+P6残: 定義不足)**:
- Added positive definition of ambiguity ("2+ implementation paths producing materially different outcomes")
- Added plausibility assessment criteria (3 exclusion rules + conservative tiebreaker for borderline cases)
- Added operational definition of LOW/MEDIUM/HIGH confidence labels

**Convergence metrics**:
- Scenario A (bug fix): critical 5/5 PASS across all iterations; unclear points 4→5→2 (decreasing); discretionary completions 2→2→0
- Scenario B (greenfield): critical 5/5 PASS; 5 unclear points identified
- Scenario C (section-extraction): critical 1/2→1.5/2→2/2 PASS; unclear points 7→5→0; discretionary completions 2→1→0