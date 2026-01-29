# Verl 镜像 - 使用示例（Console 输出为主）

> 说明：Verl 是用于 LLM 后训练 / 强化学习训练（RL）的框架。  
> 本镜像额外提供了一个 **Qwen/Qwen2.5-0.5B-Instruct 推理 demo**，方便用户验证环境可用。

## 1. 进入容器后快速验证

```bash
python -c "import verl; print('verl OK')"
python -c "import torch; print('torch OK, cuda:', torch.cuda.is_available())"
```

## 2. 运行预制 Demo（首次会下载模型）

```bash
python /workspace/demo_qwen_infer.py
```

你也可以自定义提示词与生成参数：

```bash
export DEMO_PROMPT="请用三点解释什么是 PPO。"
export MAX_NEW_TOKENS=256
export TEMPERATURE=0.7
export TOP_P=0.9
python /workspace/demo_qwen_infer.py
```

## 3. 使用 Jupyter（可选）

镜像的启动脚本与平台保持一致：**只有设置了 `JUPYTER_PASSWORD` 才会启动 JupyterLab（8888）**。

- Notebook：`/workspace/Verl_Qwen2.5_Demo.ipynb`

## 4. 缓存目录

- HuggingFace cache：`/workspace/.cache/huggingface`

> 说明：把缓存放在 /workspace 下，方便你们平台做持久化卷映射（如果有）。
