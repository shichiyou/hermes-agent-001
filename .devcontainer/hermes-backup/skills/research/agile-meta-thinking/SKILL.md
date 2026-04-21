---
name: agile-meta-thinking
description: Agile iterative thinking cycles and meta-cognition — PDCA/OODA loops, sprint design, hypothesis verification, abstraction zoom, cognitive bias countermeasures, perspective switching, and reflection practices. Load for iterative tasks, retrospectives, feeling stuck, or bias detection.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [agile, meta-thinking, meta-cognition, pdca, ooda, sprint, bias, reflection, iteration, abstraction]
    related_skills: [thinking-framework, ai-agent-conduct, plan, writing-plans]
---

# Agile Thinking Cycles & Meta-Thinking

## When to Load

Load this skill when:
- Planning or running iterative work (sprints, cycles)
- Feeling stuck or detecting circular thinking
- Suspecting cognitive bias in a decision
- Needing to adjust abstraction level (too vague / too detailed)
- Conducting retrospectives or self-assessment
- Switching perspective on a problem

## Architecture: How This Skill Relates to thinking-framework

```
┌─────────────────────────────────────────────────────────────┐
│              Agile (iterative process overall)               │
│              THIS SKILL                                     │
│              Sprint 1 → Sprint 2 → Sprint 3 → ...            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   At each granularity (Epic / Story / Task):                │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │  Meta-cognition (always-on)  ← ALSO THIS SKILL      │   │
│   │  "Is my current thinking correct?"                   │   │
│   ├─────────────────────────────────────────────────────┤   │
│   │  Thinking Framework (1 thinking cycle)               │   │
│   │  Issue→Hypothesis→Strategy→Tactics                  │   │
│   │  → see thinking-framework skill                      │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                             │
│   → Repeat at each lower granularity                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Part I: Agile Thinking Cycles

### Core Idea

Don't plan perfectly then execute. Plan small → execute → learn → adjust → repeat.

```
Traditional: Plan everything → Execute → Discover result at the end
Agile:       Plan → Execute → Learn → Plan → Execute → Learn → ...
```

### PDCA vs OODA

| Aspect | PDCA | OODA |
|--------|------|------|
| **Best for** | Stable, predictable environments | Fast-changing, uncertain environments |
| **Emphasis** | Plan accuracy | Adaptation speed |
| **Cycle speed** | Slower | Faster |
| **Origin** | Quality management | Military strategy (Boyd) |
| **Use cases** | Process improvement, quality assurance | Competitive environments, crisis response |

**PDCA Cycle**:
```
Plan → Do → Check → Act → (back to Plan)
```

**OODA Loop**:
```
Observe → Orient → Decide → Act → (back to Observe)
```

### Hypothesis Verification Loop

The core engine of agile thinking:

```
Form hypothesis
    ↓
Design verification method
    ↓
Run minimum experiment
    ↓
Learn from result
    ↓
Update or discard hypothesis
    ↓
(back to top)
```

**MVP = Minimum Viable Product for verification.** Build the smallest thing that can test the hypothesis, not the perfect thing.

**Pivot**: If the hypothesis is wrong, change direction. Treat it as learning, not failure. Minimize the cost of being wrong.

### Sprint Structure

| Element | Content | Timing |
|---------|---------|--------|
| Sprint planning | Decide what to do this sprint | Sprint start |
| Daily standup | Progress check (~15 min) | Daily |
| Sprint review | Deliverable review, feedback | Sprint end |
| Retrospective | Improve the process itself | Sprint end |

### Granularity: Epic / Story / Task & Meta-cognition

Each granularity applies meta-cognition + thinking framework:

| Granularity | Meta-cognition question | Framework application |
|------------|------------------------|----------------------|
| **Epic** | "Is this goal correct? Has the environment changed?" | Full (Issue→Hypothesis→Strategy→Tactics) |
| **Story** | "Is this feature truly needed? Is priority correct?" | Full |
| **Task** | "Is this approach efficient? Is there a better way?" | Lite (Issue→Tactics) |

**Warning**: Never lose sight of upper-level objectives while immersed in tasks. Return periodically to check Epic alignment.

### Sprint × Thinking Framework Integration

```
Sprint start
    ↓
Meta-cognition: "Am I asking the right question?"
    ↓
Issue thinking: What question does this sprint solve?
Hypothesis thinking: What is my tentative answer?
Strategy thinking: Where to concentrate?
Tactics thinking: Specifically, what to do?
    ↓
Execute
    ↓
Verify and learn
    ↓
Meta-cognition: "Was my approach correct?"
    ↓
Sprint end → Retrospective → Next sprint
```

---

## Part II: Retrospective Techniques

### KPT (Keep / Problem / Try)

Most simple retrospective framework.

| Item | Question | Example |
|------|----------|---------|
| **Keep** | What should we continue? | "Morning 30min study was effective" |
| **Problem** | What was problematic? | "Evening study lacked focus" |
| **Try** | What to try next? | "Switch evenings to review, new content in mornings" |

### YWT (Yetta / Wakatta / Tsugi — Did / Learned / Next)

Japanese-origin retrospective framework.

| Item | Content |
|------|---------|
| **Y (やったこと)** | What was actually done |
| **W (わかったこと)** | What was learned / noticed |
| **T (次にやること)** | Next actions |

### Habitual Reflection Cadence

| Frequency | Scope | Method |
|-----------|-------|--------|
| Daily | Today's actions | Journal, daily report |
| Weekly | Week's outcomes | Weekly review |
| Monthly | Monthly progress | Monthly retrospective |
| Quarterly | Big-picture direction | Quarterly review |

---

## Part III: Meta-Thinking (Thinking About Thinking)

### Three Functions of Meta-cognition

| Function | Role | Key Questions |
|----------|------|---------------|
| **Monitoring** | Observe your own thinking state | "Where am I in the process? Am I stuck? Am I on track?" |
| **Evaluation** | Judge whether thinking is appropriate | "Is this the right question? Is abstraction level right? Any bias?" |
| **Control** | Adjust the thinking process | "Course-correct. Change abstraction. Switch perspective. Pause." |

### Abstraction Zoom

**Zooming Out** (raise abstraction): Ask "Why?" "What for?" "In the first place..."

| Situation | Zoom-out question |
|-----------|-------------------|
| Means becoming the end | "What was the original purpose?" |
| Too deep in details | "What does the big picture look like?" |
| Options too narrow | "From a higher purpose, what other options exist?" |

**Zooming In** (lower abstraction): Ask "Specifically?" "For example?" "How?"

| Situation | Zoom-in question |
|-----------|-------------------|
| Too abstract to act | "What specifically does this mean?" |
| Can't move to action | "What is the very first step?" |
| Misaligned understanding | "Can you give a concrete example?" |

**Expert thinkers move freely between abstract and concrete.**
- Need to confirm purpose → zoom out
- Need to execute → zoom in
- Feeling stuck → move in the opposite direction

### Cognitive Bias Countermeasures

| Bias | Description | Countermeasure |
|------|-------------|----------------|
| **Confirmation bias** | Seeking only supporting evidence | Actively seek disconfirming evidence |
| **Anchoring** | Locked to first piece of information | Reset: "If I started fresh, what would I think?" |
| **Hindsight bias** | "I knew it all along" after the fact | Document predictions before results |
| **Sunk cost** | "We already invested this much" | Decision based on future value, not past cost |
| **Availability heuristic** | Overweighting recent/memorable info | Use data, not impressions |
| **Groupthink** | Suppressing dissent for harmony | Assign devil's advocate role |

**General bias countermeasures**:
1. **Seek disconfirmation**: Actively look for evidence against your hypothesis.
2. **Devil's advocate**: Deliberately argue the opposite position.
3. **Premortem**: "If this failed, what would be the cause?" — ask before starting.
4. **Sleep on it**: Don't decide immediately; revisit after a delay.
5. **Borrow another's perspective**: "How would person X see this?"
6. **Use numbers**: Decide with data, not feelings.

**Bias Checklist** (before important decisions):
- [ ] Am I seeking only confirming evidence?
- [ ] Am I anchored to the first information I saw?
- [ ] Am I deciding based on sunk costs?
- [ ] Have I adequately considered opposing views?
- [ ] Am I emotional about this decision?
- [ ] How would someone else view this?

### Perspective Switching

**Three dimensions**:

| Dimension | Question | Examples |
|-----------|----------|---------|
| **Viewpoint (視座)** | Whose position? | CEO? Customer? Competitor? Future self? Third party? |
| **Scope (視野)** | How wide? | Department → Company → Industry → Society |
| **Focus (視点)** | What lens? | Cost? Risk? Speed? Quality? Sustainability? |

**When stuck, switch one dimension and re-examine.**

### Breaking Through Stalled Thinking

| Pattern | Symptom | Cause | Remedy |
|---------|---------|-------|--------|
| Circular reasoning | Same discussion repeats | Issues not structured | Zoom out; restructure |
| Too deep in details | Can't see the forest | Abstraction too low | Zoom out |
| Too abstract | No concrete actions | Abstraction too high | Zoom in |
| Information paralysis | "Can't decide without more info" | No hypothesis | Set tentative answer, verify incrementally |
| Perfectionism | "There must be a better way" | No decision criteria | Set time limit; decide and iterate |

**Breakthrough techniques**:

| Technique | When to use |
|-----------|-------------|
| Change abstraction level | Circular thinking, over-detailing |
| Switch perspective | No new ideas emerging |
| Add constraints | Too many options ("Pick 3 only", "Half the budget") |
| Think in extremes | "100x? Zero?" |
| Time-box | "Decide in 10 minutes" |
| Tentative decision | "Go with this, revisit later" |
| Externalize | Write it down / talk it out |

### Reflection (リフレクション) Practice

Not just "what went wrong" but "what can I learn and apply next?"

| Category | Questions |
|----------|-----------|
| **Fact** | What happened? What did I do? |
| **Feeling** | How did I feel? Why? |
| **Interpretation** | What does this mean? Why did it happen? |
| **Learning** | What did I learn? What can I apply next? |
| **Action** | What will I change? Specifically, what next? |

---

## Anti-Patterns

| Anti-pattern | Problem | Countermeasure |
|-------------|---------|----------------|
| Over-planning | Can't start because plan isn't perfect | Start small, adjust |
| No retrospectives | Same failures repeat | Habituate reflection |
| Learn but don't apply | Verification results unused | Write learnings into next plan |
| Cycle too long | Can't adapt to change | Shorten cycles |
| Perfectionism | Can't ship MVP | "Minimum needed for verification" |
| No meta-cognition | Lost in tasks, missing objectives | Periodically ask "Is this the right question?" |

---

## Quick Reference: Which Tool When

| Situation | Use |
|-----------|-----|
| Stable environment, improving quality | PDCA cycle |
| Fast-changing, uncertain environment | OODA loop |
| Starting a new analysis | Issue → Hypothesis (thinking-framework) |
| Need to test a hypothesis | MVP + hypothesis verification loop |
| Structuring a sprint | Sprint planning + thinking framework |
| Feeling stuck | Change abstraction level or perspective |
| Suspecting bias | Bias checklist + seek disconfirmation |
| End of sprint/cycle | Retrospective (KPT or YWT) |
| Important decision ahead | Premortem + bias checklist |
| Circular thinking | Zoom out, restructure issues |

## Related Skills

- **thinking-framework**: The 1-cycle thinking process used inside each sprint/granularity.
- **ai-agent-conduct**: Behavioral principles (3-Point Check, fact-based reporting) for executing decisions.
- **plan** / **writing-plans**: Turning strategy/tactics into implementation plans.