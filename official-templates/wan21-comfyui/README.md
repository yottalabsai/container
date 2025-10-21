## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan21-comfyui

docker buildx bake wan21-comfyui --push

docker buildx bake wan21-comfyui-nunchaku --push
  
docker buildx bake comfy-all --push
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 检查 ComfyUI 是否启动
curl -s http://localhost:8188/system_stats | jq .

# 或查看队列状态
curl -s http://localhost:8188/queue | jq .