# Unsloth LLM Fine-tuning Container (Yotta Edition)

### A GPU-optimized environment for efficient LLM fine-tuning, focused on fast LoRA/QLoRA workflows with minimal memory usage.

Built on the official `unsloth/unsloth` image with an added Yotta tools layer for LLM fine-tuning (SFT / DPO / GRPO, etc.).

## Build Instructions

```bash
docker buildx bake unsloth --no-cache --push

docker build -t unsloth:local .
```

## Run (Interactive Shell)

```bash
docker run --gpus all --rm -it \
  --entrypoint /start.sh \
  yottalabsai/unsloth-yotta:TAG
```

## Tools

- yotta-info
- python + unsloth preinstalled
- branding shell environment
