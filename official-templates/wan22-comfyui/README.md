## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan22-comfyui

# 标准版（amd64+arm64）
docker buildx bake wan22-comfyui --push

# Nunchaku 版（需仓库地址）
docker buildx bake wan22-comfyui-nunchaku --push
  
docker buildx bake wan22-all --push

docker buildx bake wan22-comfyui \
  --push \
  --set WAN22_MODEL_URL=https://你自己的存储/wan2.1.safetensors

```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 系统状态
curl -s http://localhost:8188/system_stats | jq .

# 队列状态
curl -s http://localhost:8188/queue | jq .
