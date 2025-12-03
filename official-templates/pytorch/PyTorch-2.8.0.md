# PyTorch 2.8.0 Container

The **PyTorch 2.8.0 container** provides a modern, CUDA‑accelerated environment optimized for AI training and inference.  
It is commonly used for ComfyUI, diffusion models, deep learning workflows, and custom GPU pipelines.

## Key Features
- PyTorch **2.8.0** with CUDA support  
- Compatible with modern GPUs and transformer-based models  
- Includes optimized kernels for attention and matrix operations  
- Supports training, fine-tuning, and inference  
- Ideal foundation for ComfyUI, vLLM backends, and video/image models

## Use Cases
- Training deep learning models  
- Running large diffusion models (SDXL, FLUX, Wan, etc.)  
- Custom GPU inference pipelines  
- Research and experiment environments  

## Typical Ports
The base PyTorch container itself does not expose a fixed port,  
but typical services running *inside it* expose:
- **8188** → ComfyUI  
- **8000** → vLLM / LLM server  
- **9000–9100** → Custom Python services  

## Recommended Deployment
- CUDA 12.x toolchain  
- Python 3.10–3.11  
- GPU with ≥12GB VRAM for diffusion tasks  
