## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd official-templates/verl-vllm

docker buildx bake verl-vllm --push
```

## Exposed Ports

- 22/tcp (SSH)


## Test

```
docker run --gpus all --rm -it \
  -p 8000:8000 \
  your-registry/verl-vllm:latest \
  bash -lc '
    python -m vllm.entrypoints.openai.api_server \
      --host 0.0.0.0 \
      --port 8000 \
      --model "Qwen/Qwen2.5-0.5B-Instruct" \
      --trust-remote-code \
      --download-dir /workspace/hf
  '
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [
      {"role": "system", "content": "You are Qwen."},
      {"role": "user", "content": "Explain quantum entanglement in two sentences."}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'

```
