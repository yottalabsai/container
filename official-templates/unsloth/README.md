# Unsloth LLM Fine-tuning Container

基于 `nvidia/cuda` + PyTorch + [Unsloth](https://github.com/unslothai/unsloth) 的训练环境镜像，
用于大模型微调（SFT、DPO、GRPO 等）和实验开发。

---

## Build Instructions

- 使用默认配置构建：

```bash
cd containers/official-templates/unsloth

docker buildx bake
```

- 构建指定 target：

```bash
docker buildx bake unsloth
```

- 指定平台构建：

```bash
docker buildx bake unsloth   --set unsloth.platform=linux/amd64
```

- 示例（带自定义 TAG_SUFFIX）：

```bash
cd containers/official-templates/unsloth

docker buildx bake unsloth   --set TAG_SUFFIX=2025122201   --no-cache --push
```

> 如果只是本地测试，把 `--push` 去掉即可。

---

## Runtime Usage

基础用法：

```bash
docker run --gpus all --rm -it   -e HUGGINGFACE_HUB_TOKEN=hf_xxx   -v /data/unsloth-workspace:/home/ubuntu/workspace   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201
```

容器内会自动：

- 使用 `/opt/venv` 虚拟环境
- 预装好 `torch` + `unsloth[all]` + `transformers` 等依赖

你可以直接：

```bash
python - << 'PY'
from unsloth import is_good
print("Unsloth is good? ->", is_good())
PY
```

或启动 Jupyter：

```bash
jupyter lab --ip 0.0.0.0 --port 8888 --no-browser
```

然后在宿主机映射端口启动：

```bash
docker run --gpus all --rm -it   -e HUGGINGFACE_HUB_TOKEN=hf_xxx   -p 8888:8888   -v /data/unsloth-workspace:/home/ubuntu/workspace   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201   bash -lc "jupyter lab --ip 0.0.0.0 --port 8888 --no-browser"
```

---

## Exposed Ports

当前镜像本身 **不强制暴露端口**，推荐在 `docker run` 时按需映射：

- 8888/tcp – JupyterLab / Notebook（建议）
- 6006/tcp – TensorBoard（可选）

示例：

```bash
docker run --gpus all --rm -it   -p 8888:8888   -p 6006:6006   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201
```

---

## Test

镜像构建完成后，可以用下面几个命令快速自检：

### 1. 检查 Python / Torch / CUDA

```bash
docker run --gpus all --rm   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201   python - << 'PY'
import torch
print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("CUDA device count:", torch.cuda.device_count())
PY
```

### 2. 检查 Unsloth 安装

```bash
docker run --gpus all --rm   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201   python - << 'PY'
import unsloth
print("Unsloth module:", unsloth)
print("Unsloth version:", getattr(unsloth, "__version__", "unknown"))
PY
```

### 3. 简单加载一个模型（示意）

```bash
docker run --gpus all --rm -it   -e HUGGINGFACE_HUB_TOKEN=hf_xxx   yottalabsai/unsloth:cuda12.1-ubuntu22.04-2025122201   python - << 'PY'
from unsloth import FastLanguageModel

model_name = "unsloth/Meta-Llama-3-8B-Instruct-bnb-4bit"  # 示例
print("Loading model:", model_name)
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=model_name,
)
print("Loaded OK.")
PY
```

---

## Notes

- 默认用户：`ubuntu`
- 默认工作目录：`/home/ubuntu`
- Hugging Face 缓存目录：`/home/ubuntu/.cache/huggingface`
- 建议始终挂载本地 workspace + HF 缓存，减少重复下载：

```bash
-v /data/hf-cache:/home/ubuntu/.cache/huggingface -v /data/unsloth-workspace:/home/ubuntu/workspace
```

这份模板可以根据你后续加的 SSH / start.sh / 品牌元素继续扩展。
