# Wan2.2-Animate-14B — Runtime Usage Guide

This document describes how to run the **Wan-AI Wan2.2-Animate-14B** ComfyUI-enabled container, including the core environment variables, ports, and model download behavior.

Wan2.2-Animate-14B is a **14B-parameter** high-capacity video generation and animation model, integrated here as a ComfyUI runtime with automatic model downloading via `hf_download.sh`.

---

## 1. Runtime Environment Variables

The container exposes a small set of user-facing environment variables that control how the model is downloaded and loaded at startup.

### Core Variables (for most users)

| Variable | Default | Required | Description |
|---------|---------|----------|-------------|
| `WAN_MODEL_ID` | `Wan-AI/Wan2.2-Animate-14B` | false | HuggingFace model repo ID. Override to use a different Wan2.2 variant or your own fine-tuned repo. |
| `HF_TOKEN` | *(empty)* | true (for gated models) | HuggingFace access token used for downloading gated/private models if `WAN_HF_TOKEN` is not set. |
| `WAN_AUTO_DOWNLOAD` | `true` | false | When `true`, the container automatically downloads the model into `WAN_ROOT` if the directory is empty. When `false`, you must mount or pre-package the model manually. |

### Advanced Options

| Variable | Default | Description |
|---------|---------|-------------|
| `WAN_HF_TOKEN` | *(empty)* | Optional high-priority token. If set, it is used instead of `HF_TOKEN`. |
| `WAN_ROOT` | `/home/ubuntu/ComfyUI/models/wan` | Root directory under which the model will be stored. The effective path is `${WAN_ROOT}/<model-name>`. |

### Model Storage Path

By default, with `WAN_MODEL_ID=Wan-AI/Wan2.2-Animate-14B`:

```text
/home/ubuntu/ComfyUI/models/wan/Wan2.2-Animate-14B
```

If this directory exists and is non-empty, download is skipped.

---

## 2. Exposed Ports

| Port | Description |
|------|-------------|
| **8188** | ComfyUI Web UI |
| **80** | nginx reverse proxy (optional frontend entrypoint) |
| **22** | SSH access (if enabled) |

Once the container is running, ComfyUI is available at:

```text
http://localhost:8188/
```

---

## 3. Quickstart Example

Minimal recommended launch command:

```bash
docker run -it --gpus all   -e WAN_MODEL_ID="Wan-AI/Wan2.2-Animate-14B"   -e HF_TOKEN="hf_xxx"   -e WAN_AUTO_DOWNLOAD=true   -p 8188:8188   <your-image>
```

If you want to use a dedicated token and custom root:

```bash
docker run -it --gpus all   -e WAN_MODEL_ID="Wan-AI/Wan2.2-Animate-14B"   -e WAN_HF_TOKEN="hf_xxx"   -e WAN_ROOT="/home/ubuntu/ComfyUI/models/wan"   -e WAN_AUTO_DOWNLOAD=true   -p 8188:8188   <your-image>
```

On the first startup, the model will be downloaded automatically if the model directory is empty.

---

## 4. Model Auto-Download Behavior

The `post_start.sh` script implements the following logic:

| Condition | Action |
|----------|--------|
| `WAN_AUTO_DOWNLOAD=true` and `${MODEL_DIR}` is empty | Download model using `hf_download.sh` (`MODEL_DIR=${WAN_ROOT}/basename(WAN_MODEL_ID)`). |
| `WAN_AUTO_DOWNLOAD=true` and `${MODEL_DIR}` has files | Skip download. |
| `WAN_AUTO_DOWNLOAD!=true` | Do not download; assume model is already present (mounted or baked). |
| No token (`WAN_HF_TOKEN` and `HF_TOKEN` both empty) | Exit with an error for gated repositories. |

Download logs are printed to the container log and the HuggingFace cache is stored under:

```text
/home/ubuntu/.cache/huggingface
```

---

## 5. ComfyUI Runtime

After the model bootstrap phase, ComfyUI is started as:

```bash
python -u main.py   --listen 0.0.0.0   --port "${COMFYUI_PORT:-8188}"
```

Runtime logs are written to:

```text
/home/ubuntu/comfyui.log
```

---

## 6. Recommended Hardware

- **GPU VRAM**: ≥ 24–32 GB recommended for stable video generation  
- **Precision**: FP16 or BF16  
- **Use case**: high-quality text-to-video, animation, character motion, and production-style creative workflows

---

## 7. Summary

This image aims to make Wan2.2-Animate-14B easy to use:

- Configure **3 core environment variables** (`WAN_MODEL_ID`, `HF_TOKEN`/`WAN_HF_TOKEN`, `WAN_AUTO_DOWNLOAD`)  
- Expose **port 8188**  
- Let the container automatically download and manage the model under `WAN_ROOT`

The rest of the complexity is handled for you by the startup scripts and the integrated ComfyUI environment.
