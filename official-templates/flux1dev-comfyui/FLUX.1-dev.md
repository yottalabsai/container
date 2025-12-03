# black-forest-labs / FLUX.1-dev

FLUX.1-dev is the open development version of the FLUX text-to-image model family by Black Forest Labs.  
It uses a modified flow-based transformer architecture for high-quality image generation.

## Key Features
- High-quality text-to-image generation.
- Open, research-friendly "dev" version.
- Supports styles, artistic rendering, illustration, and concept art.
- Compatible with community UIs and workflows (ComfyUI, WebUI, etc.).

## Use Cases
- Illustration & art generation.
- Concept design and visual prototyping.
- Integration into image-generation pipelines.
- Research and experimentation on flow-based transformer architectures.

## Integration with ComfyUI
FLUX.1-dev is commonly used inside ComfyUI with:
- A custom pipeline loader
- Linked checkpoint files under:

/comfyui/models/diffusion_models/flux1-dev.safetensors

## Typical Runtime Ports
When running via ComfyUI:
- **8188** → ComfyUI web interface  
Optional backend services may expose:
- **9001 / 9002** → API wrappers for T2I endpoints

## Recommended Deployment
- 12–20 GB GPU VRAM
- FP16 inference
- Place checkpoints under ComfyUI’s model directory
