---
name: llm-training-workflows
description: >
  Fine-tune and train large language models efficiently. Covers LoRA/QLoRA/PEFT
  parameter-efficient tuning, PyTorch FSDP distributed training, and GRPO/TRL
  reinforcement-learning post-training with custom reward design, multi-adapter
  serving, and production inference patterns.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - llm
      - fine-tuning
      - training
      - lora
      - qlora
      - peft
      - fsdp
      - grpo
      - trl
      - reinforcement-learning
      - distributed-training
      - inference
    related_skills:
      - unsloth
      - axolotl
      - serving-llms-vllm
---

# LLM Training Workflows

> **Fine-tune, scale, and align large language models from a single skill.**

This umbrella covers three complementary training disciplines:
1. **Parameter-Efficient Fine-Tuning** — LoRA/QLoRA/PEFT: train <1% of parameters with minimal memory overhead.
2. **Distributed Scale-Out** — PyTorch FSDP: shard parameters, gradients, and optimizer states across GPUs.
3. **Reinforcement-Learning Post-Training** — GRPO with TRL: shape reasoning and structured-output behavior via reward functions without a separate reward model.

---

## Part I — Parameter-Efficient Fine-Tuning (LoRA / QLoRA / PEFT)

### When to Use PEFT
- Fine-tuning 7B–70B models on consumer GPUs (RTX 4090, A100).
- Training <1% of parameters (6 MB adapters vs. 14 GB full model).
- Need fast iteration with multiple task-specific adapters.
- Deploying multiple fine-tuned variants from one base model.

### When to Use QLoRA
- Fine-tuning 70B models on a single 24 GB GPU.
- Memory is the primary constraint; acceptable ~5% quality trade-off.

### Quick Start
```bash
pip install peft bitsandbytes
```

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
from peft import get_peft_model, LoraConfig, TaskType

model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B", torch_dtype="auto", device_map="auto")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B")
tokenizer.pad_token = tokenizer.eos_token

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    bias="none"
)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# trainable params: ~13.6 M || all params: 8.0 B || trainable%: 0.17%
```

### QLoRA (4-bit Quantized)
```python
from transformers import BitsAndBytesConfig
from peft import prepare_model_for_kbit_training

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype="bfloat16",
    bnb_4bit_use_double_quant=True
)
model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-70B", quantization_config=bnb_config, device_map="auto")
model = prepare_model_for_kbit_training(model)
# Apply same LoRA config; model now fits on single 24 GB GPU
```

### LoRA Parameter Selection
| Rank (r) | Trainable Params | Memory | Quality | Use Case |
|---|---|---|---|---|
| 4 | ~3 M | Minimal | Lower | Prototyping |
| **8** | ~7 M | Low | Good | **Recommended start** |
| **16** | ~14 M | Medium | Better | General fine-tuning |
| 32 | ~27 M | Higher | High | Complex tasks |
| 64 | ~54 M | High | Highest | Domain adaptation, 70B |

**Rule of thumb**: `alpha = 2 * rank`. Conservative: `alpha = rank`. Aggressive: `alpha = 4 * rank`.

### Target Modules by Architecture
```python
# Llama / Mistral / Qwen
target_modules = ["q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]
# GPT-2
target_modules = ["c_attn", "c_proj", "c_fc"]
# Auto-detect (PEFT 0.6+)
target_modules = "all-linear"
```

### Loading, Merging, and Multi-Adapter Serving
```python
from peft import PeftModel

# Load adapter
model = PeftModel.from_pretrained(base_model, "./lora-adapter")

# Merge into base (deployment)
merged_model = model.merge_and_unload()
merged_model.save_pretrained("./merged")

# Multi-adapter runtime switching
model.load_adapter("./adapter-task2", adapter_name="task2")
model.set_adapter("task2")

# Disable adapters (use base model)
with model.disable_adapter():
    output = model.generate(**inputs)
```

### Common Issues
| Problem | Solution |
|---|---|
| CUDA OOM | `gradient_checkpointing_enable()`, lower batch size, use QLoRA |
| Adapter not applying | Check `model.active_adapters` and `model.print_trainable_parameters()` |
| Quality degradation | Increase rank, target "all-linear", lower learning rate |

---

## Part II — Distributed Training with PyTorch FSDP

### When to Use FSDP
- Model parameters exceed single-GPU memory.
- Need to scale training across multiple nodes.

### Core Concepts
- **Parameter sharding**: each GPU holds a slice of parameters, gradients, and optimizer states.
- **Mixed precision**: bf16/fp16 for speed and memory savings.
- **CPU offloading**: offload optimizer states to host memory.
- **FSDP2** (PyTorch ≥2.2): next-generation API with improved performance.

### Patterns
- Use `FSDP` context manager and `auto_wrap_policy`.
- Enable `backward_prefetch` and `forward_prefetch` for communication overlap.
- Handle uneven inputs across workers with the Generic Join context manager.

---

## Part III — GRPO Reinforcement Learning with TRL

### When to Use GRPO
- Enforce specific output formats (XML, JSON, structured reasoning).
- Teach verifiable tasks with objective correctness metrics (math, coding, fact-checking).
- Improve reasoning capabilities by rewarding chain-of-thought patterns.
- Align models without labeled preference data.

**Do NOT use GRPO for**: simple supervised fine-tuning; tasks without clear reward signals.

### Core Concepts
- Generates **multiple completions per prompt** (group size 4–16).
- Compares completions within each group using reward functions.
- No separate reward model needed.
- Learns from within-group comparisons.

### Reward Design
Compose 3–5 reward functions covering distinct axes:

| Type | Weight | Example |
|---|---|---|
| **Correctness** | 2.0 | Exact match to ground-truth answer |
| **Format** | 0.5–1.0 | Regex match for XML/JSON structure |
| **Incremental format** | 0.0–1.0 | Partial credit per tag |
| **Length / style** | 0.1–0.5 | Conciseness or verbosity |
| **Penalty** | −0.5 | Unwanted patterns |

```python
import re

def format_reward(completions, **kwargs):
    pattern = r'<reasoning>.*?</reasoning>\s*<answer>.*?</answer>'
    responses = [comp[0]['content'] for comp in completions]
    return [1.0 if re.search(pattern, r, re.DOTALL) else 0.0 for r in responses]

def incremental_format_reward(completions, **kwargs):
    responses = [comp[0]['content'] for comp in completions]
    rewards = []
    for r in responses:
        score = 0.0
        if '<reasoning>' in r: score += 0.25
        if '</reasoning>' in r: score += 0.25
        if '<answer>' in r: score += 0.25
        if '</answer>' in r: score += 0.25
        rewards.append(score)
    return rewards
```

### Training Configs

**Memory-Optimized (Small GPU)**
```python
from trl import GRPOConfig

GRPOConfig(
    learning_rate=5e-6,
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    num_generations=8,
    max_prompt_length=256,
    max_completion_length=512,
    bf16=True,
    optim="adamw_8bit",
    max_grad_norm=0.1,
)
```

**High-Performance (Large GPU)**
```python
GRPOConfig(
    learning_rate=1e-5,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=2,
    num_generations=16,
    max_prompt_length=512,
    max_completion_length=1024,
    bf16=True,
    use_vllm=True,
)
```

### Critical Training Insights
- **Loss increases during training** — this is correct (KL divergence from initial policy). Monitor **reward**, **reward_std**, and **kl** instead.
- **Healthy progression**: reward ↑, reward_std ≥ 0.1, kl moderate.
- **Warning signs**: `reward_std → 0` (mode collapse), `kl > 0.5` (diverging too fast).

### Advanced Patterns
- **Multi-stage training**: Stage 1 format compliance → Stage 2 correctness.
- **Adaptive reward scaling**: increase weight if success rate < 30%, decrease if > 80%.
- **Custom dataset integration**: provide chat-format prompts with optional ground-truth `answer` column.

### Deployment
```python
# Merge LoRA adapters into base model for inference
merged_model = trainer.model.merge_and_unload()
merged_model.save_pretrained("production_model")
# Or serve with vLLM LoRARequest
```

---

## Pitfalls
- `execution = success` fallacy: exit code 0 ≠ desired outcome.
- Mode collapse: `reward_std` → 0 means model outputs are identical — increase `num_generations` or add diversity reward.
- OOM: reduce `num_generations`, enable gradient checkpointing, or use `adamw_8bit`.
- Forgetting to push adapter weights: LoRA adapters are small but must be saved separately from full checkpoints.
- Skipping hold-out evaluation after PEFT: merge and test on unseen data before production.

---

## Related Skills
- `unsloth` — 2–5× faster LoRA/QLoRA fine-tuning.
- `axolotl` — YAML-driven fine-tuning (LoRA, DPO, GRPO).
- `serving-llms-vllm` — high-throughput inference with LoRA adapter serving.
- `guidance` — structured output constraints at inference time.
- `outlines` — regex/grammar-constrained generation.
- `gguf-quantization` — CPU/GPU-efficient quantized inference.
