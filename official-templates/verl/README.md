# Verl (Official Template)


## 端口

- `22` SSH（平台脚本）
- `80` Nginx（平台脚本）
- `8888` JupyterLab（平台脚本：仅当设置 `JUPYTER_PASSWORD` 才启动）

## 环境变量

- `JUPYTER_PASSWORD`：开启 JupyterLab（可选）
- `MODEL_ID`：默认 `Qwen/Qwen2.5-0.5B-Instruct`
- `DEMO_PROMPT / MAX_NEW_TOKENS / TEMPERATURE / TOP_P`：控制 demo 输出

## 预制 Demo（不额外建日志文件夹，控制台输出）

进入容器后：

```bash
python /workspace/demo_qwen_infer.py
```

Notebook（Jupyter 打开后在 /workspace 可见）：

- `/workspace/Verl_Qwen2.5_Demo.ipynb`
- `/workspace/EXAMPLES.md`

## 构建

```bash
cd container/official-templates/verl
docker build -t yottalabsai/verl:dev .

docker buildx bake verl --no-cache --push
```

或使用 bake：

```bash
docker buildx bake -f docker-bake.hcl
```
