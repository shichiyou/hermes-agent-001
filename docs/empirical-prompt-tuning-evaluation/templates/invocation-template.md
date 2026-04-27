# Subagent Invocation Template

## Template for `delegate_task` Evaluation

```text
You are a blank-slate executor evaluating an agent-facing instruction for Hermes Agent.
You have no access to the parent conversation except what is written here.

## Target instruction
[Paste full target SKILL.md content or exact file path for the subagent to read]

## Scenario
[One realistic task where this instruction should be used]

## Requirements checklist
1. [critical] <minimum-bar requirement>
2. <normal requirement>
3. <normal requirement>
...

Scoring rules:
- ○ = satisfied (score 1.0)
- 部分的 = partially satisfied (score 0.5)
- × = not satisfied (score 0)
- Success requires every [critical] item to be ○

## Task
1. Follow the target instruction to execute the scenario and produce the requested deliverable or execution summary.
2. Do not repair the target instruction yourself.
3. At the end, return the report structure below.

## Required report structure
- 成果物: <artifact, summary, or concrete result>
- 要件達成:
  - 1. ○ / 部分的 / × — <reason>
  - 2. ○ / 部分的 / × — <reason>
- Trace:
  - If all phases are OK, write `Trace: all OK`.
  - Otherwise list:
    - Understanding: OK / stuck / skipped — <reason>
    - Planning: OK / stuck / skipped — <reason>
    - Execution: OK / stuck / skipped — <reason>
    - Formatting: OK / stuck / skipped — <reason>
- 不明瞭点（構造化）:
  - Issue: <observable failure or confusion>
  - Cause: <instruction-level cause>
  - General Fix Rule: <class-level rule to prevent similar failures>
- 裁量補完: <places where you had to decide something not specified>
- 再試行: <count and reason>
- 物理的証拠: <commands/files/tool outputs used to justify the result, if any>
```

## Notes for Parent Agent
- Pass exact file paths using absolute paths
- Do NOT reuse prior subagent results as hidden context
- Use narrow toolsets: `['file', 'terminal']` for local code work
- Tell the subagent it is a blank-slate executor explicitly
- Confirm scenario context is complete before dispatch
