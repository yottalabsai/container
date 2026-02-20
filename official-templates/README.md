# Official Templates

This directory contains all official Yotta Labs launch template images. Each subdirectory is a self-contained template with its own `Dockerfile`, `docker-bake.hcl`, and `README.md`.

## Templates

| Directory | Image | Description |
|-----------|-------|-------------|
| [ai-toolkit](ai-toolkit/) | `yottalabs/ai-toolkit` | Comprehensive AI/ML toolkit |
| [banana](banana/) | `yottalabs/banana` | Banana serverless inference framework |
| [base](base/) | `yottalabs/base` | Minimal runtime with CUDA, Python 3.8–3.13, and JupyterLab |
| [comfyui](comfyui/) | `yottalabs/comfyui` | AI image generation with ComfyUI |
| [comfyui-nunchaku](comfyui-nunchaku/) | `yottalabs/comfyui-nunchaku` | ComfyUI with Nunchaku quantization acceleration |
| [dflash](dflash/) | `yottalabs/dflash` | High-performance LLM inference with speculative decoding |
| [fast-stable-diffusion](fast-stable-diffusion/) | `yottalabs/fast-stable-diffusion` | Automatic1111 WebUI and DreamBooth fine-tuning |
| [flux1dev-comfyui](flux1dev-comfyui/) | `yottalabs/flux1dev-comfyui` | FLUX.1-dev image generation via ComfyUI |
| [miles](miles/) | `yottalabs/miles` | Miles AI inference framework |
| [openclaw](openclaw/) | `yottalabs/openclaw` | OpenClaw container |
| [pytorch](pytorch/) | `yottalabs/pytorch` | PyTorch 2.9 on CUDA 12.8, Python 3.11 |
| [sglang](sglang/) | `yottalabs/sglang` | SGLang inference framework |
| [skyrl](skyrl/) | `yottalabs/skyrl` | SkyRL distributed reinforcement learning framework |
| [tensorflow](tensorflow/) | `yottalabs/tensorflow` | TensorFlow with CUDA and JupyterLab |
| [unsloth](unsloth/) | `yottalabs/unsloth` | Memory-efficient LLM fine-tuning with Unsloth |
| [verl](verl/) | `yottalabs/verl` | Reinforcement learning from human feedback (RLHF) |
| [verl-vllm](verl-vllm/) | `yottalabs/verl-vllm` | VERL with vLLM for efficient rollout generation |
| [vllm-qwen](vllm-qwen/) | `yottalabs/vllm-qwen` | vLLM inference server pre-loaded with Qwen3 |
| [vs-code](vs-code/) | `yottalabs/vs-code` | Desktop VS Code development environment |
| [vscode-server](vscode-server/) | `yottalabs/vscode-server` | Browser-based VS Code Server |
| [wan21-comfyui](wan21-comfyui/) | `yottalabs/wan21-comfyui` | Wan 2.1 video generation via ComfyUI |
| [wan22-comfyui](wan22-comfyui/) | `yottalabs/wan22-comfyui` | Wan 2.2 video generation via ComfyUI |

## Template Structure

Each template directory follows this structure:

```
<template-name>/
├── Dockerfile          # Image build definition
├── docker-bake.hcl     # Buildx bake target configuration
├── README.md           # User-facing documentation (shown on Docker Hub and Yotta UI)
└── post_start.sh       # (optional) Runs after container start
```

## Building a Template

From the repository root:

```bash
docker buildx bake <target-name> --push
```

See the root [README](../README.md) for full build prerequisites and instructions.
