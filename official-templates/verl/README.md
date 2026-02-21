# Verl (Official Template)


## Exposed Ports

- `22` SSH (platform service)
- `80` Nginx (platform service)
- `8888` JupyterLab (only starts when `JUPYTER_PASSWORD` is set)

## Environment Variables

- `JUPYTER_PASSWORD`: Enable JupyterLab (optional)
- `MODEL_ID`: Default `Qwen/Qwen2.5-0.5B-Instruct`
- `DEMO_PROMPT / MAX_NEW_TOKENS / TEMPERATURE / TOP_P`: Control demo output

## Pre-built Demo

Inside the container:

```bash
python /workspace/demo_qwen_infer.py
```

Notebooks (visible at /workspace after opening JupyterLab):

- `/workspace/Verl_Qwen2.5_Demo.ipynb`
- `/workspace/EXAMPLES.md`

## Build

```bash
cd official-templates/verl
docker build -t yottalabsai/verl:dev .

docker buildx bake verl --no-cache --push
```

Or with bake:

```bash
docker buildx bake -f docker-bake.hcl
```
