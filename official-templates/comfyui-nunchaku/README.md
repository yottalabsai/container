## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/comfyui-nunchaku

docker buildx bake comfyui-nunchaku --push
docker buildx bake comfyui-nunchaku --no-cache --push
```

## Exposed Ports

- 22/tcp (SSH)
