# AI Toolkit Docker Image 构建与使用文档

本镜像用于构建并运行 **AI Toolkit** (https://github.com/ostris/ai-toolkit)，提供图像/视频训练能力，
包含 Web UI、LoRA 微调、数据库、HF 缓存、SSH 支持，专为 GPU 服务器构建。

---

## 基础信息

- CUDA: **12.8.1**
- Ubuntu: **22.04**
- Python: **3.11**
- PyTorch: **2.7.0 + cu126**
- Node.js: **23**
- SSH: Enabled
- 默认端口：**8675**

---

## 🛠️ 构建方式 (buildx bake)

### 构建默认镜像：

```bash
docker buildx bake
```

### 构建指定 target：

```bash
docker buildx bake ai-toolkit
```

### 无缓存构建：

```bash
docker buildx bake ai-toolkit --no-cache --push
```

---

## 运行镜像

```bash
docker run --rm -it --gpus all \
  -p 8675:8675 \
  -v $(pwd)/data:/data \
  -e HF_TOKEN="hf_xxx" \
  yottalabsai/ai-toolkit:latest
```

浏览器访问：

```
http://localhost:8675
```

---

## 暴露端口

| Port | 用途 |
|------|-----|
| 8675 | AI Toolkit Web UI |
| 22   | SSH 登录 |

---

## 环境变量

```yaml
HF_TOKEN: hf_xxx
AI_TOOLKIT_AUTH: 可选 UI 密码
HF_HOME: /data/huggingface
DATABASE_URL: file:/data/ai-toolkit/database/aitk_db.db
AITK_PORT: 8675
```

---

## 推荐数据目录结构

```
data/
 ├─ huggingface/
 ├─ ai-toolkit/
 │   ├─ database/
 │   ├─ output/
 └─ models/
```

---

## 健康检查

```bash
curl -s http://localhost:8675/ | head
```

---

## SSH 登录

```bash
ssh ubuntu@localhost -p 22
```

默认密码：

```
ubuntu
```

---

## 测试 Curl

```bash
curl -s http://localhost:8675/api/status
```

---

## Pull 镜像

```bash
docker pull yottalabsai/ai-toolkit:latest
```

---

## FAQ

### UI 不可访问？
检查端口映射：

```bash
docker ps
```

### GPU 无法运行？
测试：

```bash
docker run --gpus all nvidia/cuda:12.8-base nvidia-smi
```

---

## 商业品牌彩蛋

容器登录 root 自动输出：

```
Docs: https://www.yottalabs.ai/
```

yotta.txt：

```
cat /etc/yotta.txt
```

---

