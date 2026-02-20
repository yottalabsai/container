# TensorFlow

A GPU-accelerated TensorFlow container with JupyterLab, pre-configured for the Yotta platform.

## What's Included

- **TensorFlow 2.14** with GPU support
- **JupyterLab** — interactive notebook environment
- **CUDA** — GPU acceleration via NVIDIA runtime
- System toolchain: SSH, Nginx, git, wget, curl

## Exposed Ports

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 8888 | HTTP | JupyterLab |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JUPYTER_PASSWORD` | `ubuntu` | JupyterLab login password |

## Quick Start

### Verify TensorFlow and GPU

```python
import tensorflow as tf

print(tf.__version__)
print("GPUs available:", tf.config.list_physical_devices('GPU'))
```

## Build Instructions

From the repository root:

```bash
# Build and push
docker buildx bake tensorflow --push

# Build without cache
docker buildx bake tensorflow --no-cache --push
```

## Notes

- Mount `/workspace` as a persistent volume to retain notebooks and data across restarts.
- Change the default JupyterLab password by setting the `JUPYTER_PASSWORD` environment variable.
