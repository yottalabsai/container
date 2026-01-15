# PyTorch 2.9.0 Container

The **PyTorch 2.9.0 container** provides a modern, CUDA‑accelerated runtime designed for large‑scale training, fine‑tuning, and high‑performance inference workloads.

This image is intended to serve as a **general‑purpose GPU base container** and is suitable for diffusion models, LLM backends, and custom AI services running in containerized environments.

---

## Key Features

- **PyTorch 2.9.0** (Nightly / Stable)
- CUDA **12.8** toolchain
- Python **3.11**
- Optimized for NVIDIA Ampere / Ada / Hopper GPUs
- Suitable for both **training and inference**
- Includes SSH, Jupyter Lab, and Nginx for interactive workflows
- Designed for cloud GPU platforms and Kubernetes‑style deployments

---

## Included Components

- PyTorch, torchvision, torchaudio
- CUDA, cuDNN, NCCL
- Jupyter Lab (optional, environment‑controlled)
- OpenSSH server
- Nginx (basic web entry)
- Common CLI tools (git, curl, htop, tmux, vim)

---

## Runtime Behavior

When the container starts, it executes an internal startup script that:

1. Starts Nginx
2. Initializes and starts SSH
3. Optionally starts Jupyter Lab (if enabled)
4. Exports platform‑provided environment variables
5. Keeps the container running as a long‑lived service

### Startup Control

Jupyter Lab is started **only if** the following environment variable is set:

```
JUPYTER_PASSWORD=<token>
```

If unset, the container runs without Jupyter and consumes fewer resources.

---

## Exposed Ports

The container supports the following commonly used ports:

- **22/tcp** → SSH access
- **8888/tcp** → Jupyter Lab (optional)
- **80/tcp** → Nginx (static / gateway use)

> Note: Ports must be explicitly exposed or mapped by the hosting platform (Docker, Kubernetes, GPU provider).

---

## Typical Use Cases

- Training deep learning models
- Fine‑tuning large diffusion models (SDXL, FLUX, Wan, etc.)
- Running LLM inference backends
- Interactive research and experimentation
- Serving as a base image for custom AI stacks

---

## Recommended Hardware

- NVIDIA GPU with **≥12GB VRAM** (diffusion / inference)
- ≥24GB VRAM recommended for larger models
- Host driver compatible with CUDA 12.x

---

## Recommended Deployment Settings

- Linux (x86_64)
- Docker / containerd runtime
- Kubernetes, Yotta Labs, or similar GPU platforms
- Persistent volume mounted to `/workspace` for data and logs

---

## Notes on Container Startup

This image relies on its internal startup script for service initialization.

If deploying on Kubernetes or managed GPU platforms:

- Do **not** override the container `CMD` unless you explicitly call the startup script
- If a custom command is required, ensure it ends with:

```
exec /start.sh
```

Failing to do so will prevent SSH and Jupyter from starting.

---

## Intended Audience

This container is intended for:

- AI engineers
- Research engineers
- Platform / infrastructure teams
- Quantitative research and GPU compute environments

It is **not** intended as a minimal runtime image, but as a flexible and extensible base for GPU workloads.

---

## Versioning

- PyTorch: **2.9.0**
- CUDA: **12.8**
- Python: **3.11**

Future versions may introduce updated CUDA or PyTorch releases while preserving the same startup model.
