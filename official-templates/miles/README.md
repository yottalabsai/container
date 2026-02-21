# Miles AI Agent Container

### A flexible GPU environment for AI prototyping and inference, suitable for model evaluation and production-ready serving.

YottaLabs AI - Miles AI Agent Platform

Built on the official `radixark/miles` image, with added tools, SSH, Nginx, and Yotta branding.

## Quick Start

### Build and Run

```bash
cd official-templates/miles
docker buildx bake miles --no-cache --push

docker run --gpus all -d \
  --name miles-dev \
  --shm-size=16g \
  --restart unless-stopped \
  -v ~/workspace:/workspace \
  -p 8888:8888 \
  -p 80:80 \
  -p 22:22 \
  -e SSH_ENABLE=1 \
  yottalabsai/miles-yotta:latest

docker exec -it miles-dev bash
```
