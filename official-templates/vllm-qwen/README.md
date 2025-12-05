## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/vllm-qwen

HF_TOKEN=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 \
MAX_MODEL_LEN=8192 \
GPU_MEM_UTIL=0.9 \
TP_SIZE=1 \
docker buildx bake vllm-qwen --push

```

## Exposed Ports

- 22/tcp (SSH)


## Test

```
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-3B-Instruct",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "用两句话解释量子纠缠。"}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```