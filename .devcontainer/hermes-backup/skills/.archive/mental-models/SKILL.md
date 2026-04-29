---
name: mental-models
description: Multi-disciplinary mental models catalog and application framework — Inversion, Occam's Razor, First Principles, Second-Order Thinking, Circle of Competence, Margin of Safety, and ~30 key models organized by discipline. Load for deeper analysis, gap identification in reasoning, and as a "lens selection" tool when facing complex or ambiguous problems.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [mental-models, thinking, decision-making, inversion, first-principles, system-thinking, munger, multidisciplinary]
    related_skills: [thinking-framework, agile-meta-thinking, ai-agent-conduct]
    co_required: [thinking-framework]
---

# Mental Models: Multi-Disciplinary Thinking Toolkit

## When to Load

Load this skill when:
- Facing a complex, ambiguous, or novel problem
- Detecting gaps in reasoning or blind spots
- Needing to choose between competing hypotheses
- Evaluating whether a strategy/tactic has hidden failure modes
- The problem spans multiple domains (technical, organizational, economic)
- Feeling stuck or recognizing circular thinking despite existing frameworks

## Core Philosophy

**Charlie Munger**: "80 or 90 important models will carry about 90% of the freight in making you a worldly-wise person. And, of those, only a mere handful really carry very heavy freight."

Mental models are **thinking lenses** — each one reveals aspects of reality that other lenses miss. The power comes not from any single model but from **applying multiple models to the same problem** (latticework of models).

**Key distinction from existing skills**:
- `thinking-framework` = the PROCESS (Issue→Hypothesis→Strategy→Tactics)
- `agile-meta-thinking` = the ITERATION (PDCA/OODA, meta-cognition)
- `mental-models` (this skill) = the LENSES (what perspective to apply at each step)

---

## Gap Analysis: What This Skill Adds vs Existing Skills

| Mental Model | Existing Coverage | Gap Addressed |
|---|---|---|
| **Inversion** | NONE | Reverse reasoning: "How would this fail?" — directly counters confirmation bias |
| **Occam's Razor** | NONE | Hypothesis complexity penalty — prevents overfitting |
| **Map≠Territory** | ai-agent-conduct partial | Explicit "model ≠ reality" alarm at task start |
| **Second-Order Thinking** | Implicit only | Systematic enumeration of "results of results" |
| **Circle of Competence** | Implicit only | Explicit boundary check before execution |
| **Double-Loop Learning** | agile-meta-thinking partial | Explicit trigger: "when same failure repeats, discard the premise" |
| **Margin of Safety** | NONE | Buffer design for prediction error |
| **Opportunity Cost** | NONE | Explicit evaluation of alternatives not chosen |

---

## The ~30 Key Mental Models

### A. General Thinking Tools (highest utility for AI agents)

| Model | Essence | Application to AI Reasoning |
|---|---|---|
| **Map is Not the Territory** | Abstractions ≠ reality; models are simplifications | Before acting: "My understanding is a model. What might the actual situation omit?" |
| **Circle of Competence** | Know the boundary of your knowledge | Task start: "Is this within my expertise? If not, add investigation phase" |
| **First Principles Thinking** | Decompose to fundamental truths, rebuild from there | When stuck in analogy-based reasoning: strip assumptions, ask "what is necessarily true?" |
| **Thought Experiment** | Explore possibilities without real-world constraints | When options seem limited: "If constraints X/Y were removed, what would be possible?" |
| **Second-Order Thinking** | Consider consequences of consequences | After tactics design: "What happens as a result of this result? And then what?" |
| **Inversion** | Think backward: "How would I guarantee failure?" | After hypothesis: "If this hypothesis is wrong, what evidence would disprove it? What would make this approach fail catastrophically?" |
| **Occam's Razor** | The simplest explanation is most likely | When evaluating hypotheses: "Is there a simpler explanation that accounts for the same observations?" |
| **Hanlon's Razor** | Malice is often just incompetence | When attributing intent: "Can this be explained by mistake/incompetence rather than deliberate action?" |

### B. Physics, Chemistry, Biology

| Model | Essence | Application |
|---|---|---|
| **Entropy** | Disorder naturally increases; maintenance is required | "Systems degrade without active maintenance. Am I assuming stability without upkeep?" |
| **Activation Energy** | Minimum energy to start a reaction | "What's the minimum effort to trigger this change? Am I underestimating the startup cost?" |
| **Catalysts** | Accelerate reactions without being consumed | "What existing element could accelerate this without being depleted?" |
| **Critical Mass** | Self-amplifying change beyond a threshold | "Is this change below the critical mass? What would push it over?" |
| **Homeostasis** | Systems resist change to maintain equilibrium | "What restoring forces will push back against this change?" |
| **Autocatalysis** | Products catalyze their own production (positive feedback) | "Does success breed more success here? Where is the virtuous cycle?" |

### C. System Thinking

| Model | Essence | Application |
|---|---|---|
| **Feedback Loops** | Positive (amplifying) and negative (dampening) | "What feedback loops are at play? Am I seeing only one side?" |
| **Bottlenecks** | The constraint determines throughput | "What is the single bottleneck? Fixing anything else is waste." |
| **Margin of Safety** | Design buffers for prediction error | "What if I'm wrong by 2x? Does the plan still work?" |
| **Break Points** | Systems change character at thresholds | "Are we near a breakpoint where behavior changes qualitatively?" |
| **Leverage** | Small input → large output | "Where is the point of maximum leverage? Am I pushing on a rope?" |

### D. Numeracy

| Model | Essence | Application |
|---|---|---|
| **Power Laws** | Few things dominate outcomes | "Am I treating all factors as equal? The top ~20% likely drives ~80% of results." |
| **Compounding** | Small differences grow nonlinearly over time | "Am I underestimating long-term effects of small, consistent differences?" |
| **Regression to the Mean** | Extremes tend back toward average | "Is this exceptional result likely to persist, or regress?" |
| **Normal Distribution** | Most outcomes cluster near average | "Is this an outlier or within expected variation?" |

### E. Microeconomics & Strategy

| Model | Essence | Application |
|---|---|---|
| **Opportunity Cost** | The value of the best alternative not chosen | "What am I giving up by pursuing this path?" |
| **Comparative Advantage** | Specialize where you have relative strength | "Where is my relative advantage vs alternatives?" |
| **Game Theory** | Strategic interaction between agents | "How will others respond to my action? Is this a cooperate/defect situation?" |
| **Supply & Demand** | Price/availability equilibrium | "Is this scarcity real or perceived? What happens to supply if demand shifts?" |
| **Incentives** | People respond to incentives, not words | "What are the actual incentives at play, regardless of stated goals?" |

---

## Integration with Existing Skills

### Patch 1: thinking-framework Enhancement

Add after **Hypothesis Thinking** step:

```
[Inversion Check]
  "If this hypothesis is WRONG, what evidence would prove it?"
  "How would we guarantee failure with this approach?"
  → If you cannot articulate how the hypothesis could fail,
    the hypothesis is not testable.

[Occam's Razor Check]
  "Is there a simpler explanation that accounts for the same observations?"
  → Prefer the hypothesis that requires fewer assumptions.
```

Add after **Tactics Thinking** step:

```
[Second-Order Effects]
  Result → What happens as a consequence? → And then what?
  List at least 2nd-order consequences before finalizing.
  Identify one potential negative cascade.
```

### Patch 2: agile-meta-thinking Enhancement

Add to **Sprint Structure**:

```
[Circle of Competence Check] (at sprint start)
  "Is this task within my capability circle?"
  If NO → Add explicit research/investigation phase before execution.
  If PARTIAL → Identify boundary and add verification at boundary.
```

Add to **Breaking Through Stalled Thinking**:

```
[Double-Loop Learning Trigger]
  When the SAME failure pattern occurs 3+ times:
  → Stop fixing the action (single-loop).
  → Question the PREMISE/ISSUE itself (double-loop).
  → "Is the original question wrong? Are we solving the right problem?"
```

### Patch 3: ai-agent-conduct Enhancement

Add to 3-Point Check (WHY phase):

```
[Map≠Territory Awareness]
  "My current understanding is a MODEL (map), not REALITY (territory).
   What might the actual situation contain that my model omits?"
  → Before asserting completion, verify against reality, not against the model.
```

---

## Decision Tree: Which Model When

```
Problem encountered
  │
  ├─ Is the problem clearly defined?
  │    NO → First Principles: decompose to fundamentals
  │    YES ↓
  │
  ├─ Am I within my Circle of Competence?
  │    NO → Add research phase; flag uncertainty
  │    YES ↓
  │
  ├─ Do I have a hypothesis?
  │    Apply Inversion: "How would this fail?"
  │    Apply Occam's Razor: "Simpler explanation?"
  │    ↓
  │
  ├─ Is the problem systemic?
  │    YES → Identify Feedback Loops, Bottlenecks, Break Points
  │    NO ↓
  │
  ├─ Am I evaluating outcomes?
  │    Apply Second-Order Thinking
  │    Apply Margin of Safety: "What if I'm wrong by 2x?"
  │    Apply Opportunity Cost: "What am I not doing instead?"
  │    ↓
  │
  └─ Same failure repeating?
       YES → Double-Loop Learning: discard the premise
       NO → Continue execution with monitoring
```

---

## Pitfalls

- **Model overload**: Don't apply all models to every problem. Select 2-3 most relevant.
- **Map≠Territory complacency**: Knowing the model exists doesn't make you immune to confusing map with territory.
- **Inversion as pessimism**: Inversion is not negativity — it's a safety check. Still execute.
- **Occam's Razor misuse**: Simpler isn't always correct. It's a heuristic, not a law.
- **Second-Order paralysis**: Don't chase effects to infinity. 2-3 levels is sufficient.
- **Double-Loop too early**: Don't discard premises at the first failure. Only after repeated same-pattern failures.

## Related Skills

- **thinking-framework**: The process flow that mental models plug into
- **agile-meta-thinking**: The iteration engine — this skill provides lenses for each iteration
- **ai-agent-conduct**: Behavioral principles — Map≠Territory awareness strengthens fact-based reporting

## Sources

- Kenneth Craik, *The Nature of Explanation* (1943)
- Philip Johnson-Laird, *Mental Models* (1983)
- Charlie Munger, *Poor Charlie's Almanack* — multi-disciplinary model approach
- Chris Argyris, *Teaching Smart People How to Learn* — double-loop learning
- Farnam Street (fs.blog/mental-models/) — 7-category classification, ~100 models
- James Clear (jamesclear.com/mental-models) — distilled key models by discipline