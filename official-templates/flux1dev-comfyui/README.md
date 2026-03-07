## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
# Standard edition
HF_TOKEN=<your_hf_token> \
docker buildx bake flux1dev-comfyui --push

# Nunchaku edition
HF_TOKEN=<your_hf_token> \
docker buildx bake flux1dev-comfyui-nunchaku --push

# Build all variants
HF_TOKEN=<your_hf_token> \
docker buildx bake flux1dev-all --no-cache --push
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

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `HF_TOKEN` | Yes | — | HuggingFace access token |
| `FLUX_MODEL_DIR` | No | `/home/ubuntu/ComfyUI/models` | Path to store downloaded models |
| `ENABLE_FLUX_VAE` | No | `true` | Enable FLUX VAE model download |
