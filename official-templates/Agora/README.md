# Yotta × Agora — Pluralis-8B Node

Yotta official template for joining the [Pluralis-8B](https://pluralis.ai) decentralized training run via [Agora](https://github.com/PluralisResearch/agora).

## Image

```
yottalabsai/agora:cu128-py3.11-ubuntu22.04-<date>
```

| Component | Version |
|-----------|---------|
| CUDA | 12.8.1 + cuDNN |
| Python | 3.11 (conda env `agora`) |
| PyTorch | 2.7.0 + cu128 |
| Agora | latest (`main`) |

## Required Environment Variables

| Variable | Description |
|----------|-------------|
| `AGORA_HF_TOKEN` | HuggingFace read token (`hf_...`) — **required** |
| `PUBLIC_KEY` | SSH public key for remote access |

## Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGORA_EMAIL` | — | Email shown on the leaderboard |
| `AGORA_GPU_IDS` | `0` | Comma-separated GPU IDs, e.g. `0,1` for dual-GPU |
| `AGORA_ANNOUNCE_PORT` | same as host port | External port mapped to 49200 by the platform (needed on RunPod / Vast.ai where ports are remapped) |
| `JUPYTER_PASSWORD` | `ubuntu` | Jupyter Lab password |

## Ports

| Port | Service |
|------|---------|
| `22` | SSH |
| `80` | nginx landing page |
| `8888` | Jupyter Lab |
| `6006` | TensorBoard |
| `49200` | Agora node (GPU 0) |
| `49201` | Agora node (GPU 1) |

> **Note:** Port `49200` must be publicly reachable. On RunPod / Vast.ai, set `AGORA_ANNOUNCE_PORT` to the external port the platform assigns for `49200`.

## Hardware Requirements

- GPU: RTX 4090 / RTX 5090 / RTX 6000 or equivalent (≥ 24 GB VRAM)
- RAM: ≥ 80 GB
- Disk: ≥ 80 GB
- Network: ≥ 200 Mbps
- Location: **North America** (RTT < 80 ms to Agora peers)

## Monitoring

```bash
# Follow node logs
tail -f /workspace/agora/logs/server_gpu0.log

# Leaderboard
# https://agora.pluralis.ai/
```

## Build

```bash
docker buildx bake --file docker-bake.hcl
```
