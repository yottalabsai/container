# DFlash

A GPU-optimised LLM serving image that bundles PyTorch, SGLang, and DFlash (speculative decoding) into a single ready-to-run container.

## What's Included

- **PyTorch 2.9** (CUDA 12.8)
- **SGLang** — high-throughput LLM inference framework
- **DFlash** — speculative decoding engine (enabled by default)
- System toolchain: SSH, Nginx, tmux, zsh, build-essential

## Use Cases

- LLM inference serving
- Speculative decoding experiments
- GPU cloud, Kubernetes, or bare-metal deployments

## Exposed Ports

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | HTTP | Nginx proxy |
| 8888 | HTTP | JupyterLab |

## Quick Start

### Run the Container

```bash
docker run --rm -it --gpus all \
  -p 2222:22 \
  -p 8080:80 \
  yottalabsai/pytorch:2.9.0-dflash
```

### Verify CUDA and PyTorch

```bash
python - <<EOF
import torch
print(torch.__version__)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
EOF
```

### Verify DFlash

```bash
python - <<EOF
import dflash
print(dflash.__version__)
EOF
```

### Launch SGLang with DFlash (Speculative Decoding)

```bash
python -m sglang.launch_server \
  --model-path meta-llama/Llama-2-7b-hf \
  --speculative-algorithm DFLASH
```

## Build Instructions

From the repository root:

```bash
# Build and push
docker buildx bake dflash --push

# Build without cache
docker buildx bake dflash --no-cache --push
```

## Important Notes

- Do **not** override `CMD` / `ENTRYPOINT` 
— `start.sh` must run as-is.
- If you need a custom startup command in Kubernetes, end it with `exec /start.sh`.
- Mount `/workspace` as a persistent volume to preserve data across restarts.

## Pre-launch Checklist

- [ ] CUDA is available (`torch.cuda.is_available()` returns `True`)
- [ ] SGLang server starts without errors
- [ ] Speculative decoding is active
- [ ] GPU utilisation is as expected
