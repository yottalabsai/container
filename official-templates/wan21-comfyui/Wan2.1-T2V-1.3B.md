# Wan2.1‑T2V‑1.3B — Runtime Usage Guide

This document describes how to run the Wan-AI **Wan2.1‑T2V‑1.3B** ComfyUI-enabled container, including the only three environment variables users need to configure and the exposed runtime ports.

---

## Runtime Environment Variables

The container exposes **three** user-facing environment variables.  
These control how the model is downloaded and loaded at runtime.

| Variable | Default | Required | Description |
|---------|---------|----------|-------------|
| `WAN_MODEL_ID` | `Wan-AI/Wan2.1-T2V-1.3B` | false | HuggingFace model repo ID. Override this if you want to load a different Wan model or custom fork. |
| `HF_TOKEN` | *(empty)* | true (for gated models) | HuggingFace access token used for downloading gated/private models. |
| `WAN_AUTO_DOWNLOAD` | `true` | false | When `true`, model is auto-downloaded at startup if missing. When `false`, you must mount or pre‑package the model manually. |

### Model Storage Path

Downloaded model files are placed into:

```
/home/ubuntu/ComfyUI/models/wan/<model-name>
```

---

## Exposed Ports

| Port | Description |
|------|-------------|
| **8188** | ComfyUI Web UI |
| **80** | nginx reverse-proxy (optional) |
| **22** | SSH access (if enabled) |

---

## Quickstart Example

Below is a minimal, recommended way to launch the container:

```bash
docker run -it --gpus all   -e WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"   -e HF_TOKEN="hf_xxx"   -e WAN_AUTO_DOWNLOAD=true   -p 8188:8188   <your-image>
```

On first startup, the model will be downloaded automatically if the directory is empty.

---

## Model Auto-Download Behavior

| Condition | Action |
|----------|--------|
| `WAN_AUTO_DOWNLOAD=true` and model directory is empty | Auto-download using `hf_download.sh` |
| Model directory already contains files | Skip download |
| `HF_TOKEN` missing and model is gated | Script exits with error |

This ensures predictable behavior whether running on a local machine or inside a cloud GPU pod.

---

## ComfyUI Access

Once the container is running, open:

```
http://localhost:8188/
```

You will see the full ComfyUI interface with Wan2.1‑T2V‑1.3B support enabled.

---

## Notes

- GPU with **≥8 GB VRAM** is recommended.
- FP16 inference is used for efficiency.
- HuggingFace cache is located at:  
  `/home/ubuntu/.cache/huggingface`

---

## Summary

This image is designed to be extremely simple for users:  
configure **three variables**, expose **one port**, and the model runs automatically.

