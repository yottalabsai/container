# Wan-AI / Wan2.1-T2V-1.3B

Wan2.1-T2V-1.3B is a lightweight text-to-video generation model from the Wan-AI open-source video foundation model family.  
It focuses on efficient video generation with very low VRAM requirements (~8 GB), making it suitable for most consumer GPUs.

## Key Features
- 1.3B parameters — compact and efficient.
- Designed for text-to-video generation tasks.
- Supports short clip synthesis and image-guided video generation.
- Part of the Wan video foundation model suite.
- Fully open-source (weights + training code).

## Use Cases
- Lightweight video generation.
- Demo / prototype video creation.
- Integrating into local AI pipelines or ComfyUI workflows.
- Video generation for apps, research, and creative projects.

## Integration with ComfyUI
Wan2.1-T2V-1.3B can be wrapped as a custom node or Python module for:
- Text-to-video (T2V)
- Image-to-video (I2V)
- Inference via CUDA GPU pipeline

Most deployments mount:


## Typical Runtime Ports
This model itself has no "native" API server, but ComfyUI deployments usually expose:
- **8188** → ComfyUI Web UI
- **9000–9100** → Custom pipelines or service wrappers

## Recommended Deployment
- Run inside a ComfyUI container
- Use GPU with ≥8 GB VRAM
- FP16 inference recommended
