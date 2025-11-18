## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan21-comfyui

# 构建标准版
docker buildx bake wan21-comfyui --push

docker buildx bake wan21-comfyui-nunchaku --push

# 构建两个变体一起
docker buildx bake comfy-all --push

# 覆盖部分参数
docker buildx bake wan21-comfyui \
  --push \
  --set wan21-comfyui.args.TORCH_VERSION=2.4.1 \
  --set wan21-comfyui.args.TORCH_CUDA=cu124
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 检查 ComfyUI 是否启动
curl -s http://localhost:8188/system_stats | jq .

# 或查看队列状态
curl -s http://localhost:8188/queue | jq .