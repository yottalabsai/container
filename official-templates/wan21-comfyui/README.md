## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan21-comfyui

docker buildx bake wan21-comfyui \
  --set wan21-comfyui.platforms=linux/amd64,linux/arm64 \
  --set wan21-comfyui.push=true

docker buildx bake wan21-comfyui-nunchaku \
  --set wan21-comfyui-nunchaku.platforms=linux/amd64,linux/arm64 \
  --set wan21-comfyui-nunchaku.push=true
  
docker buildx bake all \
  --set wan21-comfyui.platforms=linux/amd64,linux/arm64 \
  --set wan21-comfyui.push=true \
  --set wan21-comfyui-nunchaku.platforms=linux/amd64,linux/arm64 \
  --set wan21-comfyui-nunchaku.push=true
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 检查 ComfyUI 是否启动
curl -s http://localhost:8188/system_stats | jq .

# 或查看队列状态
curl -s http://localhost:8188/queue | jq .