# Qwen3-30B-A3B-Instruct-2507

This container bundles **vLLM + CUDA 12.8 + Qwen3-30B-A3B-Instruct-2507** and automatically launches an OpenAI-compatible inference server on startup.  
No manual `vllm serve` command is required — the model is started by the container's `post_start.sh` process.

## Model Overview

**Qwen3-30B-A3B-Instruct-2507** is a high-performance Mixture-of-Experts (MoE) model with exceptional capability in long-context reasoning, multilingual understanding, programming, and agent-style tool workflows.

Key characteristics:

- ~30.5B total parameters (MoE: 128 experts, ~8 active)
- Up to **262,144-token** long-context window (hardware-dependent)
- Strong reasoning and code capabilities
- Optimized for instruction-following and conversational tasks
- Compatible with HuggingFace, vLLM, and SGLang

---

## Automatic vLLM Startup

This image automatically launches vLLM when the container starts:

- The startup script (`post_start.sh`) detects the downloaded model (or HF model ID)
- It launches vLLM with the configured runtime environment variables
- The service is immediately available at:

http://<container-ip>:8000/v1/chat/completions
http://<container-ip>:8000/v1/completions
http://<container-ip>:8000/v1/models

You do **not** need to manually run:

vllm serve Qwen/Qwen3-30B-A3B-Instruct-2507

---

## Exposed Ports

| Port | Description |
|------|-------------|
| **8000** | OpenAI-compatible vLLM API server |
| 22 | SSH access (optional, if enabled) |

---

# Runtime Configuration (Environment Variables)

The behavior of vLLM inside the container is controlled entirely through **environment variables**.  
These can be set via Docker, Kubernetes, Compose, or any runtime environment.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| **HF_TOKEN** | HuggingFace token used to download gated/private models. Leave empty if not required. | `""` |
| **MAX_MODEL_LEN** | Maximum sequence length for vLLM. Higher values require significantly more GPU memory. Typical safe values: 4096–8192 for 32–40GB GPUs; 32768+ for multi-GPU setups. | `"32768"` |
| **GPU_MEM_UTIL** | Maximum GPU memory usage allowed for vLLM (0–1). Example: `0.92` = use 92% of VRAM. Values above 0.95 may cause OOM. | `"0.92"` |
| **TP_SIZE** | Tensor parallel size. `1` = single GPU; `2`/`4` split the model across multiple GPUs. Required for long context on smaller GPUs. | `"1"` |

---

## Recommended Settings

### Single-GPU (32–40GB)
Not enough VRAM to load Qwen3-30B-A3B-Instruct.  
A single GPU must have **≥66GB** VRAM; 80GB is recommended.

### Multi-GPU (2× or 4×)
TP_SIZE=2 or 4  
MAX_MODEL_LEN=16384–65536+  
(Actual limits depend on total VRAM across all GPUs.)

### Very Large GPUs (80GB+)
MAX_MODEL_LEN up to ~32768 on a single 80GB GPU.  
Running **262144** context requires **multi-GPU** (TP ≥ 2).

---

## API Examples

Chat completion:

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-30B-A3B-Instruct-2507",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'