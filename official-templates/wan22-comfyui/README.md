## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd official-templates/wan22-comfyui

HF_TOKEN=<your_hf_token> \
docker buildx bake wan22-comfyui --no-cache --push

HF_TOKEN=<your_hf_token> \
docker buildx bake wan22-comfyui-nunchaku --no-cache --push

HF_TOKEN=<your_hf_token> \
docker buildx bake wan22-all --no-cache --push

docker buildx bake wan22-comfyui --push
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

```bash
# System status
curl -s http://localhost:8188/system_stats | jq .

# Queue status
curl -s http://localhost:8188/queue | jq .
```
