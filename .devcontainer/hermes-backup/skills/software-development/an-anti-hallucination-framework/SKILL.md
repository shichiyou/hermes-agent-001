---
name: an-anti-hallucination-framework
description: A rigorous protocol to prevent AI "hallucination of success" by replacing conceptual reporting with physical evidence and tool-driven gates.
---

# Anti-Hallucination Framework for Technical Tasks

## Trigger
Use this skill when the user expresses distrust in AI's "completion" reports, when tasks involve a high risk of "ghost completion" (reporting success without verification), or when implementing methodologies that require strict adherence to a toolchain (e.g., AI-DLC, CoDD).

## Core Principles
1. **Truth is in the Raw Output**: Never use adjectives like "successfully", "correctly", or "coherent". Use "The tool returned exit code 0" or "The raw output shows X".
2. **Hard Gates**: Do not proceed to the next step until the current step's physical evidence is presented and explicitly approved by the user.
3. **Physicality over Conceptualization**: A conceptual understanding of a methodology (e.g., "I understand CoDD") is irrelevant. Only the execution of its tools (e.g., `codd validate`) constitutes progress.

## Execution Workflow

### 1. Pre-Execution: Physical Baseline
Before any action, verify the current physical state.
- Run `ls -R`, `git status`, and `cat` on relevant config files.
- Identify exactly what exists and what is missing.

### 2. Action: Tool-Driven Execution
Every state-changing action must be preceded and followed by a tool check.
- **Pre-check**: Verify the environment (e.g., `tool --version`).
- **Execution**: Run the command.
- **Post-check**: Run a verification tool (e.g., `codd validate`, `pytest`, `grep`) to prove the outcome.

### 3. Verification: The "No-Story" Report
Report results using the following structure:
- **Command Executed**: `[Exact Command]`
- **Raw Output**: `[Full, unedited output]`
- **Physical Conclusion**: "The tool reported X, which proves Y." (No "I believe" or "It seems").

## Pitfalls to Avoid
- **Conceptual Simulation**: Avoid "acting" as if a tool was run. If the tool isn't installed, report "Tool not installed" immediately.
- **Partial Cleanup**: When removing Git submodules, never use `rm -rf` alone. Follow the full cleanup: `git rm` $\rightarrow$ `git config --remove-section` $\rightarrow$ `rm -rf .git/modules/...`.
- **The "I'm Sorry" Loop**: Avoid long apologies. Replace apologies with an immediate, correct physical operation.

## Verification Checklist
- [ ] Did I provide the Raw Output of the tool?
- [ ] Did I wait for user approval before moving to the next step?
- [ ] Did I avoid using conceptual adjectives to describe success?
- [ ] Is the physical state of the filesystem verified?
