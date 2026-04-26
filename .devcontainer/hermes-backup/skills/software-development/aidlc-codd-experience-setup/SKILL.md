---
name: aidlc-codd-experience-setup
description: Procedure for setting up a hands-on verification environment for AI-DLC combined with CoDD.
category: software-development
---

# AI-DLC x CoDD Experience Setup
This skill describes the procedure for setting up a hands-on verification environment for AI-Driven Life Cycle (AI-DLC) combined with Coherence-Driven Development (CoDD).

## Trigger
When the user wants to create a "sandbox" or "experience repository" to test AI-DLC workflows and CoDD (synchronization between docs and code).

## Workflow
1. **Infrastructure Setup**:
   - Create a dedicated directory for experiences (e.g., `experiences/`).
   - Add the canonical AI-DLC rules repository as a git submodule.
   - If write access to the submodule is needed, fork the official repo to a personal account and update the submodule pointer.

2. **Demo Project Scaffolding**:
   - Create a minimal project structure:
     - `docs/`: For CoDD-style design documents (`DESIGN.md`).
     - `src/`: For the corresponding implementation.
   - Define "Units" in `DESIGN.md` (Responsibility, Dependencies).
   - Implement the minimum viable code in `src/` that mirrors these units.

3. **Hands-on Lab Documentation**:
   - Create a `HANDS_ON_LAB.md` defining a step-by-step process:
     - Step 1: Inception (Update Design Docs).
     - Step 2: Construction (Implement based on Docs).
     - Step 3: Coherence Check (Reverse sync Code -> Docs).
     - Step 4: Audit (Verify 3-way coherence).

4. **Persistence**:
   - Commit and push changes to both the parent repository and the submodule/forked repository.

## Pitfalls
- **Submodule Permissions**: Pushing to official repos (e.g., awslabs) fails with 403. Always fork first.
- **Path Mapping**: Ensure the agent maps conceptual roots to physical paths.

## Verification
- `ls -R` confirms the structure of `aidlc-rules`, `demo-project/docs`, and `demo-project/src`.
- `git submodule status` confirms the linked repository.
