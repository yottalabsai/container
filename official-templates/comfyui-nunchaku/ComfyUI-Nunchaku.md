# ComfyUI-Nunchaku Container

This image bundles:

- ComfyUI (upstream)
- ComfyUI-Nunchaku (installed under `ComfyUI/custom_nodes/ComfyUI-Nunchaku`)
- A CUDA-enabled PyTorch stack
- Optional JupyterLab support (controlled by `JUPYTER_PASSWORD`)

## Default ports

- `8188/tcp` ComfyUI Web UI
- `22/tcp` SSH
- `8888/tcp` JupyterLab (optional)

## Key paths

- ComfyUI root: `/home/ubuntu/ComfyUI`
- Custom nodes: `/home/ubuntu/ComfyUI/custom_nodes`
- Models: `/home/ubuntu/ComfyUI/models`
- Optional persistent mount: `/workspace/storage` (see `README.md`)
