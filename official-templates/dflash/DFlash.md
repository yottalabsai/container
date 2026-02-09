# DFlash

A production-ready GPU inference container optimized for low-latency LLM serving and long-running AI services.

---

## Introduction

**DFlash** is a service-oriented GPU container designed specifically for **inference-first workloads**.
It provides a predictable, stable runtime for deploying Large Language Model (LLM) backends in
cloud and Kubernetes environments, where reliability and operational clarity matter.

DFlash is not a minimal image and not a training-focused environment.
Instead, it serves as a **reusable inference base layer** for internal platforms,
model gateways, and production AI services.

---

## Core Principles

- **Inference-first design**  
  Optimized for serving and generation, not model training.

- **Stable startup contract**  
  Clear and explicit startup behavior to avoid surprises on managed platforms.

- **Production reliability**  
  Designed for long-running GPU services with minimal operational friction.

- **Platform-friendly**  
  Works cleanly with Kubernetes and managed GPU providers.

---

## Features

- PyTorch **2.9.x**
- CUDA **12.8**
- Python **3.11**
- NVIDIA Ampere / Ada / Hopper GPU support
- Service-oriented startup model
- SSH access for debugging and maintenance
- Optional Jupyter Lab (environment-controlled)
- Nginx for lightweight HTTP entrypoints
- Common CLI and debugging tools

---

## Startup Model

DFlash relies on an internal startup script to initialize system services and
prepare the runtime environment.

At container startup:

1. Core services (SSH, Nginx) are initialized
2. Platform-provided environment variables are injected
3. Optional services (such as Jupyter Lab) are started if enabled
4. The container remains alive as a long-running GPU service host

This model allows DFlash to be used as a **base container** on top of which
custom inference servers (LLM APIs, gateways, schedulers) can be launched.

---

## Startup Contract (Important)

When deploying DFlash on Kubernetes or managed GPU platforms:

- Do **not** override the container startup command unless necessary
- If a custom command is required, it **must** end with:

```bash
exec /start.sh
```

Failing to do so may prevent essential services from starting correctly.

---

## Use Cases

- Large Language Model (LLM) inference backends
- Chat and completion APIs
- Internal model gateways and routing services
- GPU-backed microservices
- Research and evaluation inference workloads

---

## Hardware Requirements

- NVIDIA GPU with **≥16GB VRAM**
- ≥24GB VRAM recommended for larger models
- Host drivers compatible with CUDA 12.x

---

## Deployment Recommendations

- Linux (x86_64)
- Docker or containerd runtime
- Kubernetes or managed GPU platforms (e.g. Yotta Labs)
- Persistent volume mounted to `/workspace` for models and logs

---

## Intended Audience

DFlash is intended for:

- AI platform and infrastructure teams
- Backend engineers operating GPU services
- Inference and research engineers
- Organizations running LLM inference at scale

It is **not** intended as a training-focused image, but as a **stable inference foundation**.

---

## Version Information

- Runtime: **DFlash**
- PyTorch: **2.9.x**
- CUDA: **12.8**
- Python: **3.11**
