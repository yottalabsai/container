# Qwen3-30B-A3B-Instruct-2507 (vLLM Runtime Image)

This container bundles **vLLM + CUDA 12.8 + Qwen3-30B-A3B-Instruct-2507** and automatically launches an OpenAI-compatible inference server on startup.

No manual `vllm serve` command is required — the model is started automatically by the container's runtime startup process.

---

## Model Overview

**Qwen3-30B-A3B-Instruct-2507** is a high-performance Mixture-of-Experts (MoE) model designed for long-context reasoning, multilingual understanding, programming, and agent-style workflows.

**Key characteristics**

- ~30.5B total parameters (MoE: 128 experts, ~8 active)
- Up to **262,144-token** long-context window (hardware-dependent)
- Strong reasoning and code capabilities
- Optimized for instruction-following and conversational tasks
- Compatible with HuggingFace, vLLM, and SGLang

---

## Automatic vLLM Startup

When the container starts:

1. The runtime script checks whether the model exists in `$HF_HOME/$HF_MODEL_ID`
2. If not present, the model is downloaded from HuggingFace
3. vLLM is launched automatically using runtime environment variables

The OpenAI-compatible API becomes available at:

```
http://<container-ip>:<VLLM_PORT>/v1/chat/completions
http://<container-ip>:<VLLM_PORT>/v1/completions
http://<container-ip>:<VLLM_PORT>/v1/models
```

You do **not** need to manually run:

```
vllm serve Qwen/Qwen3-30B-A3B-Instruct-2507
```

---

## Exposed Ports

| Port | Description |
|------|-------------|
| **8001** | OpenAI-compatible vLLM API server |
| 22 | SSH access (optional) |

---

## Runtime Environment Variables

All runtime behavior is controlled through **environment variables**.
Changing these values does **not** require rebuilding the image.

---

### HuggingFace & Model Storage

#### `HF_HOME`

Directory used to store model files and HuggingFace cache.

Default:
```
/workspace/hf
```

Recommended to mount as a persistent volume to avoid re-downloading large models.

---

#### `HF_MODEL_ID`

HuggingFace model identifier to download and load.

Default:
```
Qwen/Qwen3-30B-A3B-Instruct-2507
```

At startup, the container checks:

```
$HF_HOME/$HF_MODEL_ID
```

If the directory exists, download is skipped.

---

#### `HF_TOKEN`

Authentication token for downloading gated or private models.

Default:
```
""
```

Only required if the model repository is not public.
Should be injected via secrets at runtime.

---

## vLLM Network Configuration

#### `VLLM_HOST`

Address vLLM binds to.

Default:
```
0.0.0.0
```

Allows access from outside the container.

---

#### `VLLM_PORT`

Port for the OpenAI-compatible vLLM API server.

Default:
```
8001
```

Using 8001 avoids common platform conflicts with port 8000.

---

## Parallelism & Memory Control

These variables determine whether the model fits into GPU memory.

---

#### `TP_SIZE`

Tensor parallel size.

Default:
```
1
```

| Value | Meaning |
|------|--------|
| 1 | Single GPU |
| 2 | Split across 2 GPUs |
| 4 | Split across 4 GPUs |

Must match the number of GPUs available to the container.

---

#### `MAX_MODEL_LEN`

Maximum supported context length (tokens).

Default:
```
32768
```

Higher values significantly increase GPU memory usage.

Guidelines:

| Hardware | Typical Safe Values |
|--------|---------------------|
| 32–40GB GPU | 4096–8192 |
| 2× GPUs | 16384–65536 |
| 80GB GPU | ~32768 |
| 262k context | Multi-GPU required |

Startup will fail if this value is set too high.

---

#### `GPU_MEM_UTIL`

Maximum GPU memory utilization allowed for vLLM.

Default:
```
0.92
```

Recommended range:

```
0.88 – 0.92  (stable)
>0.95        (high OOM risk)
```

---

## vLLM Runtime Behavior

#### `VLLM_MODEL`

Logical model name exposed via the OpenAI API.

Default:
```
Qwen3-30B-A3B-Instruct-2507
```

Does not affect which files are loaded.
Actual loading uses `$HF_HOME/$HF_MODEL_ID`.

---

#### `VLLM_TRUST_REMOTE_CODE`

Allows execution of custom model code.

Default:
```
true
```

Required for Qwen models.

---

#### `VLLM_EXTRA_ARGS`

Additional vLLM CLI arguments appended at runtime.

Default:
```
""
```

Example:
```
VLLM_EXTRA_ARGS="--dtype auto --enforce-eager"
```

---

#### `VLLM_LOG`

Path to the vLLM server log file.

Default:
```
/workspace/vllm.log
```

---

## Recommended Hardware Presets

### Single GPU (32–40GB)

Not sufficient for Qwen3-30B-A3B-Instruct.

---

### Single GPU (80GB)

```
TP_SIZE=1
MAX_MODEL_LEN=32768
GPU_MEM_UTIL=0.90–0.92
```

---

### Multi-GPU (2× or 4×)

```
TP_SIZE=2 or 4
MAX_MODEL_LEN=16384–65536
GPU_MEM_UTIL=0.92
```

262k context requires multi-GPU setups.

---

## Mental Model

Think of the container as three layers:

1. Image — CUDA, PyTorch, vLLM
2. Volume — Model weights and cache
3. Environment Variables — Runtime behavior

Most issues are resolved by adjusting:

```
TP_SIZE
MAX_MODEL_LEN
GPU_MEM_UTIL
```

No image rebuild required.
