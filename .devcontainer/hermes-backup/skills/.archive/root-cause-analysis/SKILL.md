---
name: root-cause-analysis
description: Systematic framework for diagnosing unexpected behaviors and preventing recurrence by prioritizing physical evidence over tool reports.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [debugging, troubleshooting, root-cause, la-log]
    category: software-development
---

# Root Cause Analysis (RCA) Framework

This skill is activated when an agent's reported outcome contradicts the physical state of the system (e.g., "completed" but files not updated) or when a systemic failure occurs.

## Operational Goal
Move from "symptom treatment" (quick fixes) to "structural resolution" (preventing the class of error).

## Mandatory Execution Phases

### Phase 1: Establish Ground Truth (Physicality)
Stop all assumptions. Collect raw, objective data from the system.
- **Filesystem**: Run `ls -la`, `git status`, `read_file` on affected files.
- **Processes**: Run `ps aux` and check for existence/zombie states.
- **Logs**: Inspect `agent.log`, `gateway.log`, and `errors.log` using `tail` or `grep`.
- **Result**: A "Current State" snapshot that represents the absolute truth, regardless of what the AI "thinks" happened.

### Phase 2: Gap Analysis (Expectation vs. Reality)
Compare the desired outcome with the Ground Truth.
- **The Gap**: Identify the exact point where the execution diverged from the plan.
- **Symptom Mapping**: "The agent reported X, but the system shows Y."
- **Hypothesis**: Develop 2-3 plausible reasons for the gap (e.g., "Environment misconfiguration", "Model hallucination", "Silent crash").

### Phase 3: Hypothesis Testing (Scientific Method)
Test each hypothesis one by one.
- **Isolation**: Try to reproduce the failure in a minimal setup.
- **Verification**: If a hypothesis is correct, the fix should produce a a predictable and verifiable physical change.
- **Evidence**: Document the "Before" and "After" state for each test.

### Phase 4: Permanent Mitigation (Structural Fix)
Prevent the class of error from recurring.
- **Code/Skill Fix**: Patch the underlying skill or configuration.
- **SOP Update**: Update `SOP.md` or the project wiki to include the new failure mode and its detection method.
- **Verification**: Run the failing case again to prove the fix works.

## Pitfalls to Avoid
- **The "Success" Trap**: Never trust a `success: true` return value from a tool as proof of completion.
- **Simulation Bias**: Be wary of the agent "simulating" a fix (e.g., `echo "Simulated: git push"`) instead of executing it.
- **Symptom Fixing**: Avoid "just running it again" without understanding why it failed the first time.

## Final Report Template
Every RCA must conclude with:
1. **Symptom**: (What went wrong)
2. **Root Cause**: (The technical why)
3. **Physical Proof**: (Log/Git/Process output proving the fix)
4. **Recurrence Prevention**: (What was changed in the system/SOP to stop this from happening again)
