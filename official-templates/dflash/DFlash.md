# DFlash

# **About DFlash**

**DFlash** is a production-grade GPU inference container designed for low-latency Large Language Model (LLM) serving and long-running AI services.

It provides a stable, service-oriented runtime optimized for inference workloads, making it suitable for cloud, Kubernetes, and managed GPU platforms where predictable behavior and operational reliability are critical.

------

### :confused:**The Problem: Inference Bottleneck**

Current LLMs face a "trilemma" between speed, accuracy, and efficiency: Autoregressive Models has high accuracy, but slow because they generate text sequentially (one token at a time). Speculators as EAGLE-3 offer some speedup but rely on *serial* drafting, but they are inefficient and prone to error accumulation. Standard diffusion LLM offer fast parallel generation but suffer from lower accuracy and require heavy denoising computation to maintain quality.

**How to generate GOOD tokens FAST?**

**That is a problem.**

### :arrow_down::wrench:**The DFlash Solution: Best of Both Worlds**

DFlash combines the reasoning power of large autoregressive models with the parallel speed of diffusion.

The major insight they proposed is **"The Target Knows Best."** 

Instead of forcing a small draft model to reason from scratch, DFlash leverages the rich hidden features already present in the large target model.

### **How It Works**

DFlash uses a lightweight, 5-layer diffusion model to draft tokens in parallel, conditioned on the target model's intelligence.

1. **Feature Fusion:** DFlash extracts hidden context features from the large target model .
2. **Conditioning:** These features are fed directly into the draft model. This allows the small drafter to "borrow" the deep reasoning capabilities of the large model.
3. **Parallel Drafting:** The drafter predicts a block of future tokens (e.g., 16 tokens) simultaneously using diffusion.
4. **Verification:** The target model verifies the draft in a single pass.

> **Key Design Choice:** To minimize overhead, the draft model reuses the embedding and LM head layers of the target model, training only the intermediate layers.

**Key Results**: DFlash outperforms state-of-the-art methods like EAGLE-3 on standard benchmarks (such as Math tasks).

# **Our Template**

## Key Features

- PyTorch **2.9.x** runtime
- CUDA **12.8** acceleration
- Python **3.11**
- Optimized for Ampere, Ada, and Hopper GPUs
- Suitable for LLM backends and inference APIs
- Designed for Kubernetes and cloud GPU environments

------

## Included Components

- PyTorch, torchvision, torchaudio
- CUDA, cuDNN, NCCL
- OpenSSH server for remote access and debugging
- Optional Jupyter Lab (environment-controlled)
- Nginx for lightweight HTTP entrypoints
- Common system utilities (git, curl, htop, vim, tmux)

------

## Runtime Model

DFlash follows a **service-oriented startup model**.

When the container starts:

1. Core system services (SSH, Nginx) are initialized
2. Platform-provided environment variables are injected
3. Optional interactive services (e.g., Jupyter) are started if enabled
4. The container remains alive as a long-running GPU service host

This model allows DFlash to act as a **stable base layer** for deploying LLM inference servers such as custom APIs, gateways, or internal model services.

------

## Startup Contract

DFlash relies on its internal startup script to ensure correct initialization.

When deploying on Kubernetes or managed GPU platforms:

- Do **not** override the container startup command unless necessary
- If a custom command is required, it **must** end with:

```
exec /start.sh
```

Failing to follow this contract may prevent essential services from starting correctly.

------

## Typical Use Cases

- Large Language Model (LLM) inference services
- Chat and completion APIs
- Internal model gateways
- GPU-backed microservices
- Research and evaluation inference workloads

------

## Recommended Hardware

- NVIDIA GPU with **≥16GB VRAM**
- ≥24GB VRAM recommended for larger LLMs
- Host driver compatible with CUDA 12.x

------

## Deployment Recommendations

- Linux (x86_64)
- Docker or containerd runtime
- Kubernetes, Yotta Labs, or similar GPU platforms
- Persistent volume mounted to `/workspace` for models and logs

------

## Target Audience

DFlash is intended for:

- AI platform and infrastructure teams
- Backend engineers running GPU services
- Research and inference engineers
- Organizations operating LLM inference at scale

It is not designed as a training-focused image, but as a **reliable inference foundation**.

------

## Version Summary

- Runtime: **DFlash**
- PyTorch: **2.9.x**
- CUDA: **12.8**
- Python: **3.11**