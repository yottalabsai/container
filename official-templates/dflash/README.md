# DFlash 镜像构建与测试手册（中文）

## 1. 镜像定位
本镜像是一个 **GPU Infra + LLM Serving 一体化基础镜像**，内置：
- PyTorch 2.9 (CUDA 12.8)
- SGLang
- DFlash（默认启用，用于 speculative decoding）
- 完整系统工具链（SSH / Nginx / tmux / zsh / build-essential 等）

适用于：
- LLM 推理服务
- Speculative Decoding 场景
- GPU 云平台 / Kubernetes / 裸机部署

---

## 2. 构建前置条件
- Docker >= 24
- docker buildx 已启用
- NVIDIA Driver >= 550（支持 CUDA 12.x）
- 可访问 Docker Registry（如需 push）

---

## 3. 构建镜像

### 3.1 默认构建
```bash
docker buildx bake -f docker-bake.hcl dflash
```

### 3.2 不使用缓存构建
```bash
docker buildx bake -f docker-bake.hcl dflash --no-cache
```

### 3.3 指定平台
```bash
docker buildx bake -f docker-bake.hcl dflash   --set dflash.platform=linux/amd64
```
docker buildx bake dflash --no-cache --push

---

## 4. 本地测试步骤

### 4.1 启动容器
```bash
docker run --rm -it --gpus all   -p 2222:22   -p 8080:80   yottalabsai/pytorch:2.9.0-dflash
```

### 4.2 CUDA / PyTorch 校验
```bash
python - <<EOF
import torch
print(torch.__version__)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
EOF
```

### 4.3 校验 DFlash
```bash
python - <<EOF
import dflash
print(dflash.__version__)
EOF
```

### 4.4 SGLang + DFlash 测试
```bash
python -m sglang.launch_server   --model-path meta-llama/Llama-2-7b-hf   --speculative-algorithm DFLASH
```

---

## 5. 常见注意事项
- **不要覆盖 CMD / ENTRYPOINT**
- start.sh 必须原样执行
- Kubernetes 中如需自定义 command，结尾必须 exec /start.sh
- 建议挂载 /workspace 为持久卷

---

## 6. 上线前 Checklist
- CUDA 可用
- torch.cuda.is_available == true
- sglang 可启动
- speculative decoding 生效
- GPU 利用率正常
