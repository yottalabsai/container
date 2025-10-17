## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/comfyui-flux1-dev

docker buildx bake comfyui-flux-1.dev --set comfyui-flux-1.dev.push=true

```

## Exposed Ports

- 22/tcp (SSH)


## Test

```
curl http://localhost:8188/prompt \
  -H "Content-Type: application/json" \
  -d '{"prompt":"一张未来科幻城市的黄昏场景","output_format":"png"}'

```