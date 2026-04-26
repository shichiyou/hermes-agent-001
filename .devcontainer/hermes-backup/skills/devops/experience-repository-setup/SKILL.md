---
name: experience-repository-setup
description: Set up an isolated "experience repository" using Git submodules to test methodologies (like AI-DLC x CoDD) without polluting the primary project root.
---

# Experience Repository Setup

## Trigger
When a user requests a "demo", "experience", or "verification" repository to test a specific architectural pattern, methodology, or toolset without altering the main codebase.

## Workflow

1.  **Isolate the Context**: Create a dedicated `experiences/` directory at the project root to act as a namespace for all experimental repositories.
2.  **Import Base Methodology**: Add the reference methodology (e.g., AI-DLC rules) as a Git submodule. This ensures the "canonical" rules are maintained while allowing the agent to build a specific demo project around them.
    - Command: `git submodule add <URL> experiences/<demo-name>`
3.  **Build the Application under Test (AUT)**: Create a `demo-project/` directory *inside* the submodule folder to keep the rules and the target code physically close but logically separated.
4.  **Implement Structural Alignment (CoDD Pattern)**:
    - Create a `docs/` directory for high-level design (e.g., `DESIGN.md`).
    - Create a `src/` directory for implementation.
    - Ensure the design document explicitly defines "Units" and "Dependencies" to allow for coherence verification.
5.  **Create a Manifest**: Write a `DEMO_MANIFEST.md` at the root of the experience folder to map the relationship between:
    - The Workflow Rules (AI-DLC).
    - The Target Project (Demo Project).
    - The Current State of Coherence.

## Pitfalls
- **Root Pollution**: Avoid running `git add` on the `experiences/` folder unless the intent is to commit the submodule reference.
- **Path Confusion**: Always use absolute paths or clearly defined relative paths in the manifest to avoid the agent getting lost between the rule-set and the target code.
- **Submodule Detachment**: Remember that submodules are in a detached HEAD state by default; treat them as read-only for rules and writable for the demo project.

## Verification
- Use `ls -R experiences/<demo-name>` to verify the presence of:
    1. The imported methodology rules.
    2. The `demo-project/` structure.
    3. The `DEMO_MANIFEST.md` linking them.
