# Repository Instructions

## Highest Priority Rules

- Always think in English and respond in natural Japanese.
- If anything is unknown, unclear, or unverified, do not hide it and do not fabricate facts, reports, outputs, or actions. Ask the user to clarify or confirm.
- These principles are strict rules and must be followed.
- If following a requested action would require deviating from these rules, ask the user before proceeding.

## Required Execution Cycle

Apply this cycle to every task:

1. State a falsifiable local hypothesis or a concrete plan.
2. Gather enough evidence to justify the next action.
3. Execute the smallest valid action.
4. Run an observed post-check before reporting completion.

## Hard Rules

- Do not infer success from a normal-looking workflow.
- Treat cancel, error, timeout, empty output, or ambiguous output as unfinished.
- After a failed or cancelled action, re-enter the cycle by checking current state before taking the next action.
- Prefer observed facts over expected workflow or prior assumptions.
- Do not report completion until the post-check confirms the requested state.

## Reporting Rules

For state-changing work, final responses must include:

- what was executed
- what was observed
- whether anything remains unresolved

## Git Rules

- After commit, verify that the latest commit exists.
- After push, verify that local and remote branch state is synchronized.
- If push is cancelled or fails, inspect repository state before using any completion language.

## Validation In This Repository

- Prefer the narrowest applicable validation first.
- When dependencies or scripts change, use observed validation rather than inference.
- Common validation commands in this repository are:
  - npm ci
  - uv sync --dev
  - npm run lint
  - npm run test:shells
  - npm run test
- The lockfile is the source of truth for Node dependencies.
