# FLUX.1-Dev — Model Overview & ComfyUI Runtime Usage Guide

FLUX.1-Dev is the open development version of the **FLUX text‑to‑image** family by **Black Forest Labs**.  
This image integrates FLUX.1‑Dev into a fully‑automated **ComfyUI** runtime with background model downloading, GPU‑optimized PyTorch, and optional Nunchaku support.

---

# 1. Model Summary

FLUX.1‑Dev is a research‑friendly, high‑flexibility text‑to‑image model featuring a **flow‑based transformer architecture** designed for creative generation:

- High‑quality **text → image** synthesis  
- Supports **art styles, illustration, concept design**  
- Robust prompt following  
- Efficient FP16 inference on consumer GPUs (≥12GB VRAM)

---

# 2. Key Features

- Open, development‑oriented release  
- Supports ComfyUI via modular loaders  
- Automatically downloads on container startup  
- Fully compatible with:  
  - UNET checkpoint  
  - VAE (optional)  
  - Text encoders (T5-XXL FP8 & CLIP-L)

---

# 3. Runtime Environment Variables (User‑Facing)

This container exposes **three primary variables** relevant to users, plus FLUX‑specific controls.

## Core Variables

| Variable | Default | Required | Description |
|---------|---------|----------|-------------|
| `HF_TOKEN` | *(empty)* | true | HuggingFace token required to download FLUX.1‑Dev and its text encoders. |
| `FLUX_MODEL_DIR` | `/home/ubuntu/ComfyUI/models` | false | Root directory where all FLUX files are stored. |
| `ENABLE_FLUX_VAE` | `true` | false | Enable/disable downloading and loading of the FLUX VAE (`ae.safetensors`). |

## Computed Storage Layout

On startup, files are placed under:

```
$FLUX_MODEL_DIR/unet/flux1-dev.safetensors
$FLUX_MODEL_DIR/vae/ae.safetensors              # optional
$FLUX_MODEL_DIR/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors
$FLUX_MODEL_DIR/text_encoders/clip_l.safetensors
```

If files already exist → skip download.

---

# 4. Exposed Ports

| Port | Description |
|------|-------------|
| **8188** | ComfyUI Web UI |
| **80** | nginx reverse proxy (optional UI entrypoint) |
| **22** | SSH access (if enabled) |

ComfyUI access URL:

```
http://localhost:8188/
```

---

# 5. Model Auto‑Download Logic

The loader `flux_download.sh` is automatically started in the background.

| Condition | System Action |
|----------|----------------|
| File missing | Download it via HuggingFace |
| File exists | Skip |
| VAE disabled (`ENABLE_FLUX_VAE=false`) | Do not download VAE |
| Missing HF_TOKEN | Abort with error |

Logs are written to:

```
/home/ubuntu/flux_download.log
```

---

# 6. Quickstart (Docker)

```bash
docker run -it --gpus all   -e HF_TOKEN="hf_xxx"   -e ENABLE_FLUX_VAE=true   -e FLUX_MODEL_DIR="/home/ubuntu/ComfyUI/models"   -p 8188:8188   <your-image>
```

ComfyUI will start automatically.

---

# 7. Recommended Deployment

- GPU: **12–20 GB VRAM** (RTX 4070 / 4070Ti / 4080 / 4090 / 5090 etc.)  
- Precision: **FP16**  
- Place LoRAs / checkpoints under ComfyUI’s standard model paths  
- Ensure `HF_TOKEN` has read permission for:  
  - `black-forest-labs/FLUX.1-dev`  
  - `comfyanonymous/flux_text_encoders`

---

# 8. Integration with ComfyUI

FLUX.1‑Dev files automatically populate:

```
/home/ubuntu/ComfyUI/models/diffusion_models/flux1-dev.safetensors
```

Text encoders load from:

```
/home/ubuntu/ComfyUI/models/text_encoders/
```

The loader graph typically looks like:

```
Prompt
 → Text Encoder (T5 / CLIP)
 → FLUX UNET
 → VAE Decode
 → Output
```

If VAE is disabled, workflows using external VAEs still function.

---

# 9. Summary

This container provides:

- Automated FLUX.1‑Dev provisioning  
- Complete ComfyUI runtime  
- GPU‑optimized PyTorch (CUDA 12.8, arch flags for 50‑series GPUs)  
- Optional Nunchaku support  
- Clean environment variable interface for end‑users  

A streamlined base for high‑quality image generation and research.

