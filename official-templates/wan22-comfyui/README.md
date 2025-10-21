## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan22-comfyui

# 标准版（amd64+arm64）
docker buildx bake wan22-comfyui \
  --set wan22-comfyui.platform=linux/amd64,linux/arm64 \
  --set wan22-comfyui.push=true

# Nunchaku 版（需仓库地址）
docker buildx bake wan22-comfyui-nunchaku \
  --set wan22-comfyui-nunchaku.platform=linux/amd64,linux/arm64 \
  --set wan22-comfyui-nunchaku.push=true
  
docker buildx bake wan22-all --push
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 系统状态
curl -s http://localhost:8188/system_stats | jq .

# 队列状态
curl -s http://localhost:8188/queue | jq .
