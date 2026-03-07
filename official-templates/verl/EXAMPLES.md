# Verl Image — Usage Examples

> Note: Verl is a framework for LLM post-training and reinforcement learning (RL).
> This image includes a **Qwen/Qwen2.5-0.5B-Instruct inference demo** to help you verify the environment is working.

## 1. Quick verification after entering the container

```bash
python -c "import verl; print('verl OK')"
python -c "import torch; print('torch OK, cuda:', torch.cuda.is_available())"
```

## 2. Run the pre-built demo (downloads model on first run)

```bash
python /workspace/demo_qwen_infer.py
```

You can also customize the prompt and generation parameters:

```bash
export DEMO_PROMPT="Explain what PPO is in three bullet points."
export MAX_NEW_TOKENS=256
export TEMPERATURE=0.7
export TOP_P=0.9
python /workspace/demo_qwen_infer.py
```

## 3. Using Jupyter (optional)

The image startup script follows the platform convention: **JupyterLab (port 8888) only starts when `JUPYTER_PASSWORD` is set**.

- Notebook: `/workspace/Verl_Qwen2.5_Demo.ipynb`

## 4. Cache directory

- HuggingFace cache: `/workspace/.cache/huggingface`

> The cache is placed under /workspace for easy persistent volume mapping on the Yotta platform.
