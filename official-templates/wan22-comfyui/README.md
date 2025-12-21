## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan22-comfyui

HF_TOKEN=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 \
docker buildx bake wan22-comfyui \
  --set *.args.HF_TOKEN=$HF_TOKEN \
  --no-cache --push

HF_TOKEN=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 \
docker buildx bake wan22-comfyui-nunchaku \
  --set *.args.HF_TOKEN=$HF_TOKEN \
  --no-cache --push
  
HF_TOKEN=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 \
docker buildx bake wan22-comfyui \
  --set wan22-comfyui.args.HF_TOKEN=$HF_TOKEN \
  --no-cache --push
  
HF_TOKEN=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 \
docker buildx bake wan22-comfyui \
  --no-cache --push

  
HF_TOKEN=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 \
docker buildx bake wan22-comfyui-nunchaku \
  --no-cache --push

  
HF_TOKEN=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 \
docker buildx bake wan22-all \
  --set *.args.HF_TOKEN=$HF_TOKEN \
  --no-cache --push

docker buildx bake wan22-comfyui \
  --push \

```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 系统状态
curl -s http://localhost:8188/system_stats | jq .

# 队列状态
curl -s http://localhost:8188/queue | jq .
