## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/pytorch

docker buildx bake pytorch290 --no-cache --push

docker buildx bake pytorch290 --push
```

## Exposed Ports

- 22/tcp (SSH)
