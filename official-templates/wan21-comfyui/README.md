## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/wan21-comfyui

# 构建标准版
HF_TOKEN=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 \
docker buildx bake wan21-comfyui \
  --no-cache --push

HF_TOKEN=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 \
docker buildx bake wan21-comfyui-nunchaku \
  --no-cache --push

# 构建两个变体一起
docker buildx bake wan21-all --no-cache --push

HF_TOKEN=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 \
docker buildx bake wan21-all \
  --no-cache --push

# 覆盖部分参数
docker buildx bake wan21-comfyui --no-cache --push
```

## Exposed Ports

- 8188/tcp (ComfyUI Web UI / API)
- 22/tcp (SSH)


## Test

# 检查 ComfyUI 是否启动
curl -s http://localhost:8188/system_stats | jq .

# 或查看队列状态
curl -s http://localhost:8188/queue | jq .


# ==== 手动操作说明（容器内）====
# 1）手动下载 Wan2.1 模型：
   export WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"
    export WAN_MODEL_DIR="/home/ubuntu/ComfyUI/models/wan2.1-t2v-1.3b"
    export WAN_AUTO_DOWNLOAD="true"
    export HF_TOKEN="hf_xxx"


# 2）手动启动 ComfyUI：
   sudo -u ubuntu bash -lc '
     cd /home/ubuntu/ComfyUI && \
     python -u main.py --listen 0.0.0.0 --port 8188
   '
