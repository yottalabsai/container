# DFlash PyTorch Container – Overview & Usage

## Overview
This container is a **GPU-optimized base image** designed for modern LLM inference and serving workloads.

It ships **out-of-the-box** with:
- PyTorch 2.9 (CUDA 12.8)
- SGLang
- DFlash (default-enabled speculative decoding)
- Full system tooling (SSH, Nginx, tmux, build tools)

The image is intended for **production inference**, not as a minimal runtime.

---

## Key Features
- CUDA 12.8 + cuDNN + NCCL
- Python 3.11
- Speculative decoding via **DFlash**
- Optimized for Ampere / Ada / Hopper GPUs
- Ready for Docker, Kubernetes, and cloud GPU platforms

---

## Why DFlash
DFlash enables **speculative decoding**, significantly improving:
- Token throughput
- End-to-end latency
- GPU utilization

It is particularly effective for:
- Large language model serving
- High-QPS inference backends
- Interactive LLM applications

---

## Running the Container

```bash
docker run --gpus all -it   -p 22:22   -p 80:80   yottalabsai/pytorch:2.9.0-dflash
```

---

## Using DFlash with SGLang

```bash
python -m sglang.launch_server   --model-path meta-llama/Llama-2-7b-hf   --speculative-algorithm DFLASH
```

DFlash is enabled by default — no additional configuration is required.

---

## Typical Use Cases
- LLM inference services
- Speculative decoding research
- GPU cloud platforms
- Internal AI infrastructure

---

## Deployment Notes
- Requires NVIDIA driver compatible with CUDA 12.x
- Do not override the container startup script
- Recommended to mount persistent storage to /workspace

---

## What This Image Is Not
- Not a minimal runtime image
- Not CPU-only
- Not intended for environments without NVIDIA GPUs
