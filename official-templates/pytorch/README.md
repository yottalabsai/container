
# PyTorch Container – Build & Architecture Guide

## File Structure & Layer Responsibilities

```text
containers/official-templates/pytorch/
├── gpu-runtime.Dockerfile
├── os-base.Dockerfile
├── python-runtime.Dockerfile
├── ml-runtime.Dockerfile
├── runtime.Dockerfile
├── docker-bake.hcl
└── README.md
```

### gpu-runtime.Dockerfile
GPU 运行时能力层（当前为 CUDA 实现）。  
仅负责 GPU runtime，本身不包含 OS / Python / ML 逻辑。  
未来如切换 ROCm 或 CPU-only，仅需修改此文件。

### os-base.Dockerfile
操作系统基础层（语言无关）：
- 系统工具（git / curl / wget）
- 编译工具链（build-essential）
- 系统服务依赖（ssh / nginx）
- locale / timezone / sudo

### python-runtime.Dockerfile
Python 运行时层：
- 从源码编译指定 Python 版本（如 3.11.14）
- 初始化 pip / setuptools / wheel
- 不包含任何 ML 或业务依赖

### ml-runtime.Dockerfile
ML 能力层：
- PyTorch（CUDA 对应版本）
- JupyterLab / Notebook
- HuggingFace / datasets
- NCCL tests

### runtime.Dockerfile
最终运行镜像：
- 用户与权限
- SSH / nginx 配置
- branding 文件
- start.sh（必须原样保留）
- EXPOSE 与 CMD

---

## Build Chain (docker buildx bake)

```text
gpu-runtime
   ↓
os-base
   ↓
python-runtime
   ↓
ml-runtime
   ↓
pytorch290
```

通过 `docker-bake.hcl` 中的：

```
contexts = {
  base = "target:上一层"
}
```

将上一层 target 的产物注入为下一层的基础镜像。

---

## Build Instructions

```bash
docker buildx bake
```

构建指定 target：

```bash
docker buildx bake pytorch290
```

强制全量重建并推送：

```bash
docker buildx bake pytorch290 --no-cache --push
```

后台构建（推荐）：

```bash
nohup docker buildx bake   --allow=fs.read=/root/projects/container/container-template   pytorch290   --no-cache   --push   > bake-pytorch290.log 2>&1 &
```

---

## Exposed Ports

- 22/tcp  SSH
- 80/tcp  nginx
- 8888/tcp JupyterLab
