# Security Policy

## Reporting A Vulnerability

Do not open a public issue for suspected security vulnerabilities.

Instead, use GitHub's private vulnerability reporting flow for this repository if it is enabled. If that flow is not available, contact the repository owner privately through GitHub and include:

- a clear description of the issue
- affected files or commands
- reproduction steps
- impact assessment if known

## Response Expectations

Maintainers will review reports as time permits and may ask for clarification or a minimal reproduction.

## Scope Notes

This repository is a development-environment baseline. Security-relevant reports may include:

- unsafe default container behavior
- credential handling mistakes in scripts or documentation
- command injection or privilege escalation paths in setup scripts
- supply-chain risks introduced by installation or update flows

Vendor-specific service behavior outside this repository is generally out of scope unless this baseline directly introduces the risk.
