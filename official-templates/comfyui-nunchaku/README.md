# comfyui-nunchaku (official template)

This template builds a GPU-ready ComfyUI image with the **ComfyUI-Nunchaku** custom node preinstalled.

## Build

```bash
cd container/official-templates/comfyui-nunchaku
docker buildx bake comfyui-nunchaku
```

Push example:

```bash
docker buildx bake comfyui-nunchaku --push
```

## Runtime

- **SSH**: `22/tcp`
- **ComfyUI Web UI**: `8188/tcp`
- **JupyterLab** (optional): `8888/tcp` (enabled when `JUPYTER_PASSWORD` is set)

### Environment variables

- `COMFYUI_HOST` (default `0.0.0.0`)
- `COMFYUI_PORT` (default `8188`)
- `COMFYUI_EXTRA_ARGS` (default empty)
- `JUPYTER_PASSWORD` (optional, enables JupyterLab via immutable `/start.sh`)
- `PUBLIC_KEY` (optional, adds SSH authorized key via immutable `/start.sh`)

### Persistent storage (optional)

If you mount `/workspace/storage`, the container will try to symlink:

- `/workspace/storage/custom_nodes/*` → `ComfyUI/custom_nodes/*`
- `/workspace/storage/models/*` → `ComfyUI/models/*`
- `/workspace/storage/workflows` → `ComfyUI/user/default/workflows`

(Implemented in `boot.sh`.)
