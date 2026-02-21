## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd official-templates/sglang

docker buildx bake sglang --push
```

## Exposed Ports

- 22/tcp (SSH)
- 30000/tcp SGLang OpenAI

## Test

```
ps aux | grep sglang
ss -tlnp | grep 30000 || netstat -tlnp | grep 30000

curl -X POST http://localhost:30000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-3B-Instruct",
    "prompt": "Explain quantum entanglement in two sentences.",
    "sampling_params": {
      "temperature": 0.7,
      "max_tokens": 256
    }
  }'

```
