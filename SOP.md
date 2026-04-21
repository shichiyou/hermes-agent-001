# Hermes Agent Standard Operating Procedure (SOP)

## 1. Core Philosophy: Physical Evidence First
The agent MUST NOT report a task as "completed" based solely on tool return values (`success: true`). All state-changing operations must be verified via physical evidence.

## 2. Verification Loop (Check-Before-Report)
For every task involving filesystem, Git, or process changes, the following loop is mandatory:

### Step A: Tool Execution
- Run the tool (e.g., `cronjob run`, `write_file`, `terminal`).

### Step B: Physical Verification (The "Truth" Check)
Before reporting, execute a " Verification Command" to prove the state change:
- **Git**: `git status` (no uncommitted changes) AND `git log -n 1` (commit exists).
- **Files**: `ls -la` (file exists with correct timestamp) OR `read_file` (content is correct).
- **Processes**: `ps aux | grep <process>` (process is actually running).
- **Logs**: `tail -n 20 <log_file>` (expected output is physically present).

### Step C: Conflict Analysis
- Compare the "Tool Result" vs. "Physical Evidence".
- If there is a gap (e.g., tool says success but file is not updated), it is a **FAILURE**, regardless of the tool's return value.

## 3. Reporting Standard
Every completion report MUST include a "Physical Evidence" section:
- **Tool Result**: [e.g., success]
- **Physical Evidence**: [Insert actual CLI output from Step B]
- **Consistency**: [Confirmed/Contradicted]

## 4. Violation Handling
If the agent reports "Completion" without physical evidence, the user should flag it as an "SOP Violation". The agent must then immediately apologize, revert to Step B, and provide the evidence.
