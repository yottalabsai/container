# ComfyUI-Nunchaku Container

**ComfyUI‑Nunchaku** is a high‑performance extension of ComfyUI optimized for large video-generation models such as Wan2.1, Wan2.2, AnimateDiff, and other advanced pipelines.

It focuses on improving throughput, runtime stability, batching, and GPU memory utilization for heavy T2V workloads.

## Key Features
- Built on top of ComfyUI with performance enhancements  
- Optimized for text‑to‑video and animation pipelines  
- Supports Wan‑AI models out of the box  
- Better long‑sequence scheduling for video frames  
- Efficient GPU memory reuse & graph optimizations  
- Plugin‑compatible with standard ComfyUI nodes

## Directory Layout
```
/comfyui-nunchaku/
/comfyui-nunchaku/models/
/comfyui-nunchaku/wan/
/comfyui-nunchaku/output/
/comfyui-nunchaku/cache/
```

## Typical Ports
- **8189** → Web UI (Nunchaku dashboard)
- **9200–9300** → High‑throughput video-generation service endpoints

## Usage
ComfyUI‑Nunchaku is ideal for:
- Heavy text‑to‑video pipelines  
- Long clip generation  
- Batch rendering jobs  
- High‑performance inference in production environments  

