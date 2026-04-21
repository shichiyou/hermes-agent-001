# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-04-17

### Added

- Dependency maintenance scripts (`check-package-updates.sh`, `check-python-package-updates.sh`) with accompanying Bats test suites
- Docker Compose configuration with `docker-socket-proxy` for secure Docker access inside the devcontainer
- `AGENTS.md` defining AI agent behavior and security policies
- Expanded Bats test suite (`post-create`, `post-start`, `update-tools`, `check-package-updates`, `check-python-package-updates`)
- Project initialization guidance documents (`docs/project-init.md`, `docs/project-init.ja.md`)
- GitHub Copilot repository instructions (`.github/copilot-instructions.md`) and project-init prompt template
- Agent configuration files (`.claude/settings.json`, `.codex/rules/default.rules`)
- AI agent security design document (`docs/superpowers/specs/2026-04-16-ai-agent-security-design.md`)

### Changed

- Extended devcontainer lifecycle scripts (`post-create.sh`, `post-start.sh`, `update-tools.sh`) with additional tooling and automation
- Updated TypeScript to v6.0.3
- Added Docker healthcheck to `docker-proxy` service in `docker-compose.yml`
- Updated `README.md`, `CONTRIBUTING.md`, and their Japanese equivalents

### Fixed

- Restored executable permissions (`100755`) on 11 `.devcontainer` shell scripts that were committed as `100644`, causing Bats tests to fail with exit status 126 (Permission Denied)
- Tightened CI "Verify shell script permissions" step to actively exit with failure when any `*.sh` under `.devcontainer` lacks the executable bit

## [1.0.0] - 2026-04-05

### Added

- Initial OSS release
- Dev Container baseline for Python and TypeScript monorepos
- Shared shell script libraries (`logging.sh`, `retry.sh`, `version.sh`, `workspace.sh`)
- bats shell script test suite
- Bilingual documentation (English primary, Japanese supplementary)
- GitHub issue and pull request templates
- CODEOWNERS and FUNDING.yml configuration
- Changelog and license headers (SPDX identifiers)
