# Yotta Labs — Hermes Agent

> **vLLM inference server + [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) CLI, built for NVIDIA Blackwell GPUs (RTX 5090 / sm_120)**

Run Hermes-series models with a fully OpenAI-compatible `/v1` API — drop-in replacement for any client that speaks the OpenAI protocol. Includes the **hermes CLI** for interactive terminal chat.

---

## Quick Start

### On the Yotta Platform

Deploy this template from the [Yotta Labs platform](https://yottalabs.ai). The server starts automatically — no configuration required.

### With Docker

```bash
docker run -d --gpus all \
  -p 22:22 -p 80:80 -p 8000:8000 -p 8888:8888 \
  -e HF_TOKEN=hf_YOUR_TOKEN \
  -v /workspace:/workspace \
  yottalabsai/hermes:latest
```

The container will:
1. Start **nginx**, **SSH**, and **JupyterLab** services
2. Launch **vLLM** in the background and wait for it to become healthy
3. Auto-configure **hermes-agent** to point at the local vLLM server

> **First boot** takes 3–5 minutes to download the model from Hugging Face and load it onto the GPU. Subsequent starts reuse the cache and are much faster.

### Access Your Endpoints

| Service | URL | Credential |
|---|---|---|
| OpenAI-compatible API | `http://<pod-ip>:8000/v1` | `api_key="EMPTY"` |
| JupyterLab | `http://<pod-ip>:8888` | token: `yotta` |
| SSH | `ssh root@<pod-ip> -p 22` | via `PUBLIC_KEY` env var |
| nginx proxy | `http://<pod-ip>:80` | — |

---

## Environment Variables

All runtime behaviour is controlled via environment variables — no image rebuild needed.

### Model & Inference

| Variable | Default | Description |
|---|---|---|
| `HERMES_MODEL` | `NousResearch/Hermes-3-Llama-3.1-8B` | Hugging Face model ID to serve |
| `VLLM_SERVED_MODEL_NAME` | `hermes` | Model alias in the API (`model` field) |
| `VLLM_MAX_MODEL_LEN` | `8192` | Maximum context window (tokens) |
| `VLLM_GPU_MEMORY_UTILIZATION` | `0.90` | Fraction of GPU VRAM for KV cache |
| `VLLM_TRUST_REMOTE_CODE` | `true` | Allow remote code in model repos |
| `VLLM_EXTRA_ARGS` | *(see below)* | Additional CLI flags passed to vLLM |
| `VLLM_STARTUP_TIMEOUT` | `600` | Max seconds to wait for vLLM health check |

Default `VLLM_EXTRA_ARGS`:
```
--enable-prefix-caching --enable-auto-tool-choice --tool-call-parser hermes --no-enable-log-requests
```

### Networking

| Variable | Default | Description |
|---|---|---|
| `VLLM_HOST` | `0.0.0.0` | vLLM listen address |
| `VLLM_PORT` | `8000` | vLLM listen port |
| `OPENAI_BASE_URL` | `http://localhost:8000/v1` | OpenAI-compatible base URL |

### Hugging Face

| Variable | Default | Description |
|---|---|---|
| `HF_TOKEN` | _(unset)_ | Hugging Face access token (required for gated models) |
| `HF_HOME` | `/workspace/.cache/huggingface` | Cache directory for downloaded models |
| `HF_HUB_ENABLE_HF_TRANSFER` | `1` | Use `hf_transfer` for faster downloads |

### Access

| Variable | Default | Description |
|---|---|---|
| `JUPYTER_PASSWORD` | `yotta` | JupyterLab access token |
| `PUBLIC_KEY` | _(unset)_ | SSH public key for passwordless login |

### Switch to a Different Model

```bash
docker run -d --gpus all \
  -e HF_TOKEN=hf_YOUR_TOKEN \
  -e HERMES_MODEL=meta-llama/Llama-3.1-70B-Instruct \
  -e VLLM_SERVED_MODEL_NAME=llama70b \
  -e VLLM_MAX_MODEL_LEN=4096 \
  -e VLLM_GPU_MEMORY_UTILIZATION=0.95 \
  -p 8000:8000 \
  yottalabsai/hermes:latest
```

---

## Using the vLLM API

The server is fully **OpenAI-compatible**. Use any OpenAI client — just point it at your pod.

### Python (openai SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<pod-ip>:8000/v1",
    api_key="EMPTY",
)

response = client.chat.completions.create(
    model="hermes",
    messages=[
        {"role": "system", "content": "You are Hermes, a helpful AI assistant."},
        {"role": "user", "content": "Explain vLLM prefix caching in one paragraph."},
    ],
    temperature=0.7,
    max_tokens=512,
)
print(response.choices[0].message.content)
```

### curl — Chat Completion

```bash
curl http://<pod-ip>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hermes",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

### curl — Tool Calling

```bash
curl http://<pod-ip>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hermes",
    "messages": [{"role": "user", "content": "What is the weather in SF?"}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for a city",
        "parameters": {
          "type": "object",
          "properties": {"city": {"type": "string"}},
          "required": ["city"]
        }
      }
    }]
  }'
```

### Health Check & Model List

```bash
curl http://<pod-ip>:8000/health
curl http://<pod-ip>:8000/v1/models
```

---

## Using the Hermes CLI

The `hermes` CLI is pre-installed and auto-configured to use the local vLLM server.

```bash
# Interactive chat
hermes chat

# Check configuration
hermes config

# View installed model
hermes model
```

The auto-generated configuration lives at `/root/.hermes/config.yaml`:

```yaml
model:
  default: "hermes"
  provider: custom
  base_url: "http://localhost:8000/v1"
  api_key: "EMPTY"
  context_length: 8192

terminal:
  backend: local

approvals:
  mode: "off"
```

---

## Persistent Storage

Mount a volume to `/workspace` to cache model weights across pod restarts:

```
/workspace/.cache/huggingface   ← model weights cache (HF_HOME)
/workspace/vllm.log             ← vLLM server log
/workspace/jupyter.log          ← JupyterLab log
```

---

## Logs & Troubleshooting

| Log | Location |
|---|---|
| vLLM server log | `/workspace/vllm.log` |
| JupyterLab log | `/workspace/jupyter.log` |
| Container stdout | `docker logs <container>` |

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| vLLM timeout on startup | Model download is slow | Set `HF_TOKEN`; check network; increase `VLLM_STARTUP_TIMEOUT` |
| CUDA out of memory | Model too large for GPU | Reduce `VLLM_MAX_MODEL_LEN` or `VLLM_GPU_MEMORY_UTILIZATION` |
| Port 8000 already in use | Another process on the port | The entrypoint will detect this; check `lsof -i :8000` |

---

## Building from Source

```bash
cd official-templates/hermes

# Build locally
docker buildx bake

# Build and push
docker buildx bake --push

# Build without cache
docker buildx bake --no-cache --push
```

The `docker-bake.hcl` defines the build target, tags, and default arguments.

---

## Stack

| Component | Detail |
|---|---|
| Base image | `nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04` |
| CUDA | 12.8.1 |
| Python | 3.11 (deadsnakes PPA) |
| PyTorch | Nightly cu128 (Blackwell sm_120) |
| vLLM | Latest stable from PyPI |
| hermes-agent | NousResearch/hermes-agent (latest) |
| Entrypoint | `tini` (PID 1) → `/start.sh` |

---

## License

Apache 2.0 © [Yotta Labs](https://yottalabs.ai)

Model weights are subject to their respective upstream licenses (see [NousResearch on HuggingFace](https://huggingface.co/NousResearch)).
