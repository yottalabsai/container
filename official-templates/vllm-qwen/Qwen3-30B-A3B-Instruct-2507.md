# Qwen3-30B-A3B-Instruct-2507

Qwen3-30B-A3B-Instruct-2507 is a state-of-the-art 30B Mixture-of-Experts (MoE) language model designed for high-quality reasoning, coding, multilingual tasks, and instruction following.

## Key Features
- ~30.5B total parameters (128 experts, ~8 active).
- Extremely long context window: **262,144 tokens**.
- Strong performance in reasoning, programming, multilingual tasks, and agent/tool usage.
- Optimized "Instruct" tuning for conversational and directive tasks.
- Compatible with HuggingFace, vLLM, and SGLang.

## Use Cases
- Chatbots & AI assistants
- Long-document reading & summarization
- Code generation and debugging
- Knowledge reasoning
- Agent-style tools & workflow automation

## Deployment with vLLM
Qwen3-30B-A3B-Instruct-2507 is typically served using:

```bash
vllm serve Qwen/Qwen3-30B-A3B-Instruct-2507 \
  --max-model-len 262144 \
  --host 0.0.0.0 \
  --port 8000
```

### Exposed Ports
- **8000** – vLLM OpenAI-compatible inference server  
  - `/v1/chat/completions`
  - `/v1/completions`
  - `/v1/models`

(Optional)
- **8001–8010** Additional ports for multi-worker deployments.

## Recommended Deployment
- GPU: ≥80GB VRAM (A100/H100) or Multi-GPU with tensor parallelism
- Framework: vLLM 0.5+ or sglang
- Inference: FP16 or BF16
