# Wan-AI / Wan2.2-Animate-14B

Wan2.2-Animate-14B is a high-capacity video generation and animation model.  
Compared to Wan2.1, this 14B-parameter model delivers richer motion, better temporal consistency, and higher resolution outputs.

## Key Features
- 14B parameters — significantly more expressive and detailed.
- Designed for advanced animation and high-quality text-to-video generation.
- Supports image-to-video, talking portrait generation, and instruction-guided animation.
- Built for creative production and more demanding video generation tasks.

## Use Cases
- High-quality video generation.
- Animation, character motion, stylized sequences.
- Instruction-controlled video editing.
- Creative studio / production workflows.

## Integration with ComfyUI
The 14B model can be integrated into ComfyUI using:
- Custom nodes
- External Python backend loaded into ComfyUI workflow

Common folder structure:

/comfyui/models/wan2.2-animate/

## Typical Runtime Ports
Same as other ComfyUI-based deployments:
- **8188** → ComfyUI Web Dashboard
- **9000–9100** → Backend video-generation services (optional)

## Recommended Deployment
- ≥ 24–32 GB GPU VRAM (A100, 4090, H100 class preferred)
- Use FP16 or BF16 computation
- Run inside a ComfyUI-enabled GPU container
