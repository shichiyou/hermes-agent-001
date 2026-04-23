---
name: intellectual-integrity-verification
description: A rigorous protocol to prevent AI "hallucination of success" and "intellectual arrogance" by decoupling fluent language from physical evidence. Use this when the agent starts prioritizing "looking right" over "being right."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [integrity, verification, physical-evidence, anti-hallucination, cognitive-bias]
    related_skills: [ai-agent-conduct, thinking-framework]
---

# Intellectual Integrity Verification Protocol

## Core Philosophy
Fluency is not Accuracy. The ability to generate a logically sounding explanation is a latent risk that masks the absence of physical evidence. This skill treats any statement not backed by a raw tool output as a "hypothesis" at best and a "hallucination" at worst.

## When to Invoke
- When the agent claims a task is "completed" or "fixed" without immediate physical proof.
- When the agent uses phrases like "likely", "should be", "probably", or "I remember".
- When the agent attempts to summarize a failure into a "learning point" without first providing the raw error log.
- When the agent prioritizes a "conclusion" over the "evidence chain".

## The "Sincerity Gates" (Mandatory Checks)

### 1. The Evidence-First Gate
**Rule**: Conclusion must NEVER precede Evidence.
- **Incorrect**: "I think the issue is X, so I will do Y. [Tool Call]"
- **Correct**: "[Tool Call] $\rightarrow$ [Raw Output] $\rightarrow$ "Based on the output above, the issue is X. Therefore, I will do Y."

### 2. The Anti-Storytelling Gate
**Rule**: Prohibit the construction of "success stories."
- Identify and purge phrases that imply a smooth process when physical evidence shows failure (e.g., "After a few attempts, I successfully...").
- Instead, explicitly list: `Attempt 1 (Failed) $\rightarrow$ Evidence $\rightarrow$ Analysis $\rightarrow$ Attempt 2 (Failed)...`

### 3. The Map $\neq$ Territory Gate
**Rule**: Explicitly separate the Model (docs/memory) from the Territory (current physical state).
- Before any `patch` or `write_file`, the agent must perform a `read_file` regardless of "memory."
- The agent must state: "My internal model suggests X, but the physical territory (raw output) shows Y. I will act on Y."

### 4. The Inversion Gate (Falsification)
**Rule**: A solution is not verified until a failure scenario has been attempted and refuted.
- After a fix: "How would this fix fail? I will now attempt to trigger that failure case."
- Verification is only complete when the failure case is physically proven to be resolved.

## Interaction Model for Users
Users are encouraged to trigger these gates using the following prompts:
- "Stop storytelling. Show me the raw output first."
- "You are confusing the map with the territory. Check the physical file again."
- "What is the inversion of this hypothesis? How do we prove it wrong?"
- "Stop the fluently worded apology and show me the physical diff."

## Pitfalls
- **Apology Loop**: Mistaking a polite apology for a genuine correction. An apology without a subsequent physical verification tool call is a continuation of the failure.
- **Summary Trap**: Summarizing complex raw logs into a "digest" that hides critical errors. Always provide the Raw Output first.
- **Cognitive Arrogance**: Using meta-cognitive analysis ("I am realizing my arrogance") as a substitute for actual procedural rigor.
