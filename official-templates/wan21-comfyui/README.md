## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd official-templates/wan21-comfyui

# Build standard edition
HF_TOKEN=<your_hf_token> \
docker buildx bake wan21-comfyui --no-cache --push

HF_TOKEN=<your_hf_token> \
docker buildx bake wan21-comfyui-nunchaku --no-cache --push

# Build both variants together
HF_TOKEN=<your_hf_token> \
docker buildx bake wan21-all --no-cache --push

# Build without model download
docker buildx bake wan21-comfyui --no-cache --push
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

```bash
# Check if ComfyUI is running
curl -s http://localhost:8188/system_stats | jq .

# Or check queue status
curl -s http://localhost:8188/queue | jq .
```

## Manual Operations (inside the container)

```bash
# 1) Manually download Wan2.1 model:
export WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"
export WAN_MODEL_DIR="/home/ubuntu/ComfyUI/models/wan2.1-t2v-1.3b"
export WAN_AUTO_DOWNLOAD="true"
export HF_TOKEN="<your_hf_token>"

# 2) Manually start ComfyUI:
sudo -u ubuntu bash -lc '
  cd /home/ubuntu/ComfyUI && \
  python -u main.py --listen 0.0.0.0 --port 8188
'
```
