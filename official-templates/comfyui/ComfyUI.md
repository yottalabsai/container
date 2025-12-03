# ComfyUI Container

The **ComfyUI container** provides a modular, node‑based interface for image, video, and multimodal AI workflows.  
It is commonly used for running diffusion models, video-generation backends, and custom pipelines.

## Key Features
- Visual node graph for building multimodal workflows  
- Supports SDXL, LCM, FLUX, Wan, and custom checkpoint-based models  
- GPU‑accelerated execution (CUDA)  
- Plugin-friendly architecture  
- Easy integration with REST APIs, extensions, and custom nodes

## Default Directory Layout
```
/comfyui/
/comfyui/models/
/comfyui/custom_nodes/
/comfyui/output/
/comfyui/input/
```

## Typical Ports
- **8188** → Web UI (primary ComfyUI dashboard)
- **9000–9100** → Optional backend services or custom API nodes

## Usage
ComfyUI is ideal for:
- Text‑to‑image generation
- Image‑to‑image workflows
- Video generation backends via custom nodes
- Interactive creative pipelines

