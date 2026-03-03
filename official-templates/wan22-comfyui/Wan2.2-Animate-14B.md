# Wan 2.2 Animate - ComfyUI

Pre-configured **ComfyUI** environment with **Wan 2.2 Animate 14B** model for high-quality image-to-video generation.

## What's Included

- ✅ **Wan 2.2 Animate 14B** (FP8 optimized, ~28GB)
- ✅ **ComfyUI** web interface on port 8188
- ✅ **Pre-loaded models**: I2V diffusion models, VAE, text encoder, LoRAs
- ✅ **PyTorch 2.4.1** with CUDA 12.1 support
- ✅ **Python 3.11** runtime environment

## Model Capabilities

**Wan 2.2 Animate** specializes in:
- **Image-to-Video (I2V)**: Transform static images into smooth animations
- **High/Low Noise Models**: Dual noise configurations for quality control
- **LightX2V LoRAs**: 4-step acceleration for faster generation
- **14B Parameters**: State-of-the-art video generation quality

## Using ComfyUI

### Web Interface

1. Click "Connect" or  open  `http://<your-pod>:8188` in your browser
2. Load workflow from ComfyUI Manager
3. Upload your input image
4. Configure generation parameters:
   - **Steps**: 4-50 (use LoRA for 4-step generation)
   - **Noise Level**: High/Low (two separate models)
   - **Resolution**: Up to 1024×1024
5. Click **Queue Prompt** to generate

### Pre-installed Models

Located in `/home/ubuntu/ComfyUI/models/`:

| Type | Model | Purpose |
|------|-------|---------|
| Diffusion | `wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors` | High noise I2V |
| Diffusion | `wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors` | Low noise I2V |
| Text Encoder | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | Text conditioning |
| VAE | `wan2.2_vae.safetensors` | Video encoder/decoder |
| LoRA | `wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors` | 4-step acceleration (high) |
| LoRA | `wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | 4-step acceleration (low) |

## System Requirements

- **GPU**: Recommended RTX 5090

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `COMFYUI_PORT` | `8188` | ComfyUI web interface port |
| `PYTHON_VERSION` | `3.11` | Python runtime version |
| `TORCH_VERSION` | `2.4.1` | PyTorch version |

## Tips for Best Results

1. **Use LoRAs for speed**: Enable 4-step LoRAs for 10× faster generation
2. **Choose noise level**: High noise for creative results, low noise for faithful reproduction
3. **Image quality matters**: Higher resolution inputs produce better outputs
4. **Aspect ratio**: 16:9 or 1:1 work best

## Troubleshooting

### Check ComfyUI logs
```bash
tail -f /home/ubuntu/comfyui.log
```

### Verify models are loaded
```bash
ls -lh /home/ubuntu/ComfyUI/models/diffusion_models/
ls -lh /home/ubuntu/ComfyUI/models/vae/
``



