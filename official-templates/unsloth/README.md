# Unsloth LLM Fine-tuning Container (Yotta Edition)

### A GPU-optimized environment for efficient LLM fine-tuning, focused on fast LoRA/QLoRA workflows with minimal memory usage.

基于官方 `unsloth/unsloth` 镜像，叠加 Yotta 工具层，用于大模型微调（SFT / DPO / GRPO 等）。

## Build Instructions

```bash
docker buildx bake \
  --allow=fs.read=/root/projects/container/container-template \
  unsloth --no-cache --push
  
docker buildx bake unsloth --no-cache --push
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
