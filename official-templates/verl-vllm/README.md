## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/verl-vllm

docker buildx bake verl-vllm --push \
  --set verl-vllm.args.VLLM_MODEL="Verl/Wan2.2"
```

## Exposed Ports

- 22/tcp (SSH)


## Test

```
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Verl/Wan2.2",
    "messages": [
      {"role": "system", "content": "You are Verl."},
      {"role": "user", "content": "用两句话解释量子纠缠。"}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```