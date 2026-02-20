# Yotta Labs Container Images

This repository contains the Dockerfiles for the official [Yotta Labs](https://yottalabs.ai) launch template images. All images are published to [Docker Hub](https://hub.docker.com/u/yottalabs) and are ready to deploy on the Yotta platform.

## Available Templates

| Template | Docker Image | Description |
|----------|-------------|-------------|
| [Base](official-templates/base/) | `yottalabs/base` | Minimal runtime with CUDA, Python 3.8–3.13, and JupyterLab |
| [PyTorch](official-templates/pytorch/) | `yottalabs/pytorch` | PyTorch 2.9 on CUDA 12.8, Python 3.11, JupyterLab |
| [TensorFlow](official-templates/tensorflow/) | `yottalabs/tensorflow` | TensorFlow with CUDA and JupyterLab |
| [ComfyUI](official-templates/comfyui/) | `yottalabs/comfyui` | AI image generation with ComfyUI |
| [ComfyUI Nunchaku](official-templates/comfyui-nunchaku/) | `yottalabs/comfyui-nunchaku` | ComfyUI with Nunchaku quantization acceleration |
| [Flux 1.0 Dev](official-templates/flux1dev-comfyui/) | `yottalabs/flux1dev-comfyui` | FLUX.1-dev image generation via ComfyUI |
| [Wan 2.1](official-templates/wan21-comfyui/) | `yottalabs/wan21-comfyui` | Wan 2.1 video generation via ComfyUI |
| [Wan 2.2](official-templates/wan22-comfyui/) | `yottalabs/wan22-comfyui` | Wan 2.2 video generation via ComfyUI |
| [Fast Stable Diffusion](official-templates/fast-stable-diffusion/) | `yottalabs/fast-stable-diffusion` | Automatic1111 WebUI and DreamBooth fine-tuning |
| [DFlash](official-templates/dflash/) | `yottalabs/dflash` | High-performance LLM inference with speculative decoding |
| [SGLang](official-templates/sglang/) | `yottalabs/sglang` | SGLang inference framework |
| [vLLM + Qwen](official-templates/vllm-qwen/) | `yottalabs/vllm-qwen` | vLLM inference server pre-loaded with Qwen3 |
| [Unsloth](official-templates/unsloth/) | `yottalabs/unsloth` | Memory-efficient LLM fine-tuning with Unsloth |
| [VERL](official-templates/verl/) | `yottalabs/verl` | Reinforcement learning from human feedback (RLHF) |
| [VERL + vLLM](official-templates/verl-vllm/) | `yottalabs/verl-vllm` | VERL with vLLM for efficient rollout generation |
| [SkyRL](official-templates/skyrl/) | `yottalabs/skyrl` | SkyRL distributed reinforcement learning framework |
| [Miles](official-templates/miles/) | `yottalabs/miles` | Miles AI inference framework |
| [AI Toolkit](official-templates/ai-toolkit/) | `yottalabs/ai-toolkit` | Comprehensive AI/ML toolkit |
| [VS Code](official-templates/vs-code/) | `yottalabs/vs-code` | Desktop VS Code development environment |
| [VS Code Server](official-templates/vscode-server/) | `yottalabs/vscode-server` | Browser-based VS Code Server |

## Container Requirements

All official images must include the following to integrate with the Yotta platform:

### Dependencies

- `nginx` — Port proxying to the user-facing interface
- `openssh-server` — SSH access to the container
- `jupyterlab` — JupyterLab notebook access

### `yotta.yaml`

Each container folder must include a `yotta.yaml` describing its version and exposed services:

```yaml
version: '1.0.0'
services:
  - name: 'my-service'
    port: 9000
    proxy_port: 9001
```

### `README.md`

Each container folder must include a `README.md`. This file is displayed on Docker Hub and in the Yotta platform UI. It is also served to users when a proxied port is not yet ready.

## Building Images

All images are built using [Docker Buildx Bake](https://docs.docker.com/build/bake/). Each template has its own `docker-bake.hcl` — run bake commands from **inside the template directory**.

### Prerequisites

```bash
# Install QEMU for multi-platform builds
docker run --privileged --rm tonistiigi/binfmt --install all

# Create and activate a Buildx builder with the docker-container driver
docker buildx create --name yotta-builder --driver docker-container --use
docker buildx inspect --bootstrap
```

### Build Commands

```bash
cd official-templates/<template-name>

# Build using the default target
docker buildx bake

# Build and push
docker buildx bake --push

# Build without cache and push
docker buildx bake --no-cache --push
```

Replace `<template-name>` with the directory name (e.g., `pytorch`, `comfyui`, `dflash`).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding or modifying templates.

## Security

To report a security vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Yotta Labs
