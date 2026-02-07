## Build Instructions

- To build with the default options, simply run `docker buildx bake`.
- To build a specific target, use `docker buildx bake <target>`.
- To specify the platform, use `docker buildx bake <target> --set <target>.platform=linux/amd64`.

Example:

```bash
cd containers/official-templates/pytorch

docker buildx bake pytorch290 --no-cache --push

docker buildx bake pytorch290 --push

nohup docker buildx bake \
  --allow=fs.read=/root/projects/container/container-template \
  pytorch290 \
  --no-cache \
  --push \
  > bake-pytorch290.log 2>&1 &


```

## Exposed Ports

- 22/tcp (SSH)

