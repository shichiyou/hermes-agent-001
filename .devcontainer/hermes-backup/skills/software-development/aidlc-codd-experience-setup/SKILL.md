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
1. **Create an independent lab directory/repository**:
   - Prefer a normal project directory such as `experiences/aidlc-codd-graphify-lab/` or a new standalone repo.
   - Do **not** fork or modify `awslabs/aidlc-workflows` for the lab. Treat it as an upstream rule source, not as the lab's parent project.
   - Do **not** add `aidlc-workflows`, `codd-dev`, or `graphify` as submodules unless the user explicitly wants to study their source code.

2. **Install AI-DLC from the official distribution path**:
   - Use the `awslabs/aidlc-workflows` release zip (`ai-dlc-rules-v<version>.zip`) and copy `aidlc-rules/` into the target project according to the official platform-specific setup.
   - Verify the chosen assistant integration physically exists, e.g. `.kiro/`, `.cursor/`, `CLAUDE.md`, `AGENTS.md`, `.aidlc-rule-details/`, etc. depending on the platform.
   - Verify AI-DLC workflow execution by observing generated `aidlc-docs/`, especially `aidlc-docs/aidlc-state.md` and `aidlc-docs/audit.md`.

3. **Install and run CoDD using the official CLI**:
   - Install with `pip install codd-dev` or a project virtual environment equivalent.
   - For greenfield: run `codd init --project-name ... --language ... --requirements ...`, then `codd plan --init`, `codd generate`, `codd validate`, `codd implement`, `codd assemble` as appropriate.
   - For brownfield: run `codd extract`, `codd require`, `codd plan --init`, `codd scan`, `codd impact`, `codd audit --skip-review`, `codd measure` as appropriate.
   - Verify CoDD artifacts physically exist: `codd.yaml`, `codd/` or `.codd/` scan/cache outputs, generated design docs with `codd:` YAML frontmatter containing `node_id`, `depends_on`, and source/module mappings.

4. **Install and run Graphify using the official CLI**:
   - Install the official package `graphifyy`, e.g. `uv tool install graphifyy && graphify install`, `pipx install graphifyy && graphify install`, or a project venv.
   - Run `/graphify .` or the platform-specific invocation; for Codex use `$graphify .`.
   - Run the relevant always-on integration if desired, e.g. `graphify claude install`, `graphify codex install`, `graphify hermes install`, etc.
   - Verify `graphify-out/graph.json` and `graphify-out/GRAPH_REPORT.md` exist. If using Codex, verify `.codex/hooks.json`; if using Claude Code, verify `CLAUDE.md` and hook settings; if using Hermes, verify `AGENTS.md`/skill integration as documented.

5. **Three-way coherence closure**:
   - After code or design changes, run and record the article's intended loop: `codd extract` → `codd validate` → `graphify --update` or `/graphify --update` → `graphify query ...`.
   - Record Raw Output in the lab README: command, exact output, generated files, and what each output proves.

6. **Persistence**:
   - Commit only the intentional lab project files and generated verification artifacts that are meant to be shared.
   - Do not commit ad-hoc research reports or external source clones into the parent repository; route those to `~/workspace/` per workspace hygiene rules.

## Pitfalls
- **Do not fork AI-DLC as the lab substrate**: Forking `awslabs/aidlc-workflows` and adding `demo-project/` only imitates the concept. It does not prove official AI-DLC setup, CoDD setup, or Graphify setup.
- **Submodule mismatch hazard**: A parent `.gitmodules` entry can point to `awslabs/aidlc-workflows` while the submodule's internal `origin` points to a personal fork. Always verify both parent `.gitmodules` and submodule `git remote -v` before trusting the setup.
- **Concept imitation is not verification**: A hand-written `docs/DESIGN.md` plus `src/*.py` is not CoDD unless `codd` is installed, frontmatter exists, and `codd validate`/`scan` outputs are observed.
- **Graphify is absent until outputs exist**: Claims of graph-based architecture understanding require `graphify-out/graph.json` and `graphify-out/GRAPH_REPORT.md`; otherwise no graph was built.
- **AI-DLC is absent until `aidlc-docs/` exists**: Rules copied into a repo are not enough. Workflow execution should produce `aidlc-docs/aidlc-state.md` and `aidlc-docs/audit.md`.
- **Path Mapping**: Ensure the agent maps conceptual roots to physical paths.

## Verification
- `git status --short --branch` and `git submodule status --recursive` confirm the lab is not an accidental fork/submodule of the tool repositories.
- `git config -f .gitmodules --get-regexp 'submodule\\..*' || true` and, for any submodule, `git -C <path> remote -v` confirm no parent/internal URL mismatch.
- `command -v codd && codd --version` confirms CoDD installation; `codd validate`/`codd scan` Raw Output confirms actual CoDD operation.
- `command -v graphify && graphify --version` confirms Graphify installation; `test -f graphify-out/graph.json` and `test -f graphify-out/GRAPH_REPORT.md` confirm graph generation.
- `test -f aidlc-docs/aidlc-state.md` and `test -f aidlc-docs/audit.md` confirm AI-DLC workflow artifacts.
- `grep -R "^codd:" -n docs aidlc-docs 2>/dev/null` or equivalent confirms CoDD frontmatter exists.
