# vLLM + Qwen

A production-ready LLM inference image built on [vLLM](https://github.com/vllm-project/vllm), pre-loaded with **Qwen3-30B-A3B-Instruct** and served via an OpenAI-compatible HTTP API.

## What's Included

- **PyTorch** (nightly, CUDA 12.8)
- **vLLM** — high-throughput LLM inference engine
- **Qwen3-30B-A3B-Instruct** — pre-downloaded at build time
- System toolchain: SSH, Nginx, tmux, zsh

## Exposed Ports

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 8001 | HTTP | vLLM OpenAI-compatible API |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_MODEL` | `Qwen/Qwen3-30B-A3B-Instruct-2507` | Model identifier |
| `VLLM_PORT` | `8001` | API server port |
| `TP_SIZE` | `1` | Tensor parallel size |
| `MAX_MODEL_LEN` | `32768` | Maximum context length |
| `GPU_MEM_UTIL` | `0.92` | GPU memory utilisation fraction |
| `VLLM_EXTRA_ARGS` | _(empty)_ | Additional vLLM server arguments |

## API Usage

Once the container is running, the vLLM server exposes an OpenAI-compatible endpoint:

```bash
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/workspace/hf/Qwen/Qwen3-30B-A3B-Instruct-2507",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain quantum entanglement in two sentences."}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

## Build Instructions

The model is downloaded at **build time**, so a HuggingFace token is required. Pass it as a build argument:

```bash
# Build and push (token passed at build time, not stored in the image)
HF_TOKEN=<your-hf-token> docker buildx bake vllm-qwen --no-cache --push
```

> The token is used only during the build stage to download the model weights.
> It is **not** baked into the final image layers.

## Notes

- Mount `/workspace` as a persistent volume to retain model weights across container restarts.
- Adjust `TP_SIZE` to match the number of GPUs available (e.g., `TP_SIZE=4` for four GPUs).
- Set `VLLM_EXTRA_ARGS` to pass additional flags directly to the vLLM server.
