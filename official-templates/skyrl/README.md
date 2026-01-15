# SkyRL Reinforcement Learning Container

YottaLabs AI - SkyRL Training Platform

基于官方 `skypilot/skypilot` 镜像，集成 Ray、Gymnasium、SSH、Nginx 等工具的强化学习训练环境。

## 快速开始

### 1. 构建镜像

```bash
cd ~/projects/container/official-templates/skyrl
docker buildx bake skyrl --no-cache
```

### 2. 启动容器（推荐配置）

```bash
# 清理旧容器（如果存在）
docker rm -f skyrl-dev

# 启动容器
docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  --restart unless-stopped \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  -p 6379:6379 \
  -p 8888:8888 \
  -p 22:22 \
  -e JUPYTER_PASSWORD="your-secure-password" \
  -e SSH_ENABLE=1 \
  yottalabsai/skyrl-yotta:latest
```

### 3. 查看容器状态

```bash
# 查看运行状态
docker ps | grep skyrl-dev

# 查看启动日志
docker logs skyrl-dev

# 查看实时日志
docker logs -f skyrl-dev
```

### 4. 进入容器

```bash
docker exec -it skyrl-dev bash
```

## 容器内验证

### 快速验证所有组件

```bash
# 保存为 /workspace/test_skyrl.sh
cat > /workspace/test_skyrl.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "Testing SkyRL Container"
echo "=========================================="

# 1. 检查 Nginx
echo -e "\n1. Nginx Status:"
service nginx status && echo "✓ Nginx OK" || echo "✗ Nginx failed"

# 2. 检查 SSH
echo -e "\n2. SSH Status:"
pgrep -x sshd && echo "✓ SSH OK" || echo "✗ SSH failed"

# 3. 检查 Branding
echo -e "\n3. Yotta Branding:"
cat /etc/yotta.txt

# 4. 检查 GPU
echo -e "\n4. GPU Status:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader && echo "✓ GPU OK" || echo "✗ GPU failed"

# 5. 测试 Ray
echo -e "\n5. Testing Ray:"
python << 'PYTHON_EOF'
import ray
print("\n" + "="*50)
print("Testing Ray")
print("="*50)
ray.init(ignore_reinit_error=True)
print(f"✓ Ray version: {ray.__version__}")
print(f"✓ Available resources: {ray.available_resources()}")
ray.shutdown()
print("="*50 + "\n")
PYTHON_EOF

# 6. 测试 Gymnasium
echo -e "\n6. Testing Gymnasium:"
python << 'PYTHON_EOF'
import gymnasium as gym
print("\n" + "="*50)
print("Testing Gymnasium")
print("="*50)
env = gym.make("CartPole-v1")
print(f"✓ Environment: {env.spec.id}")
print(f"✓ Action space: {env.action_space}")
print(f"✓ Observation space: {env.observation_space}")
env.close()
print("="*50 + "\n")
PYTHON_EOF

echo -e "\n=========================================="
echo "All tests completed!"
echo "=========================================="
EOF

chmod +x /workspace/test_skyrl.sh
bash /workspace/test_skyrl.sh
```

### 单独验证各组件

#### 验证 Nginx

```bash
service nginx status
# 或
curl -I http://localhost
```

#### 验证 SSH

```bash
ps aux | grep sshd
```

#### 验证 GPU

```bash
nvidia-smi
```

#### 验证 Ray

```bash
python << 'EOF'
import ray
print("\n" + "="*50)
print("Testing Ray")
print("="*50)
ray.init(ignore_reinit_error=True)
print(f"✓ Ray version: {ray.__version__}")
print(f"✓ Available resources: {ray.available_resources()}")
ray.shutdown()
print("="*50 + "\n")
EOF
```

#### 验证 Gymnasium

```bash
python << 'EOF'
import gymnasium as gym
print("\n" + "="*50)
print("Testing Gymnasium")
print("="*50)
env = gym.make("CartPole-v1")
print(f"✓ Environment: {env.spec.id}")
print(f"✓ Action space: {env.action_space}")
print(f"✓ Observation space: {env.observation_space}")
env.close()
print("="*50 + "\n")
EOF
```

## 常用命令

### 容器管理

```bash
# 停止容器
docker stop skyrl-dev

# 启动容器
docker start skyrl-dev

# 重启容器
docker restart skyrl-dev

# 删除容器
docker rm -f skyrl-dev

# 查看容器资源使用
docker stats skyrl-dev

# 查看容器详细信息
docker inspect skyrl-dev

# 查看端口映射
docker port skyrl-dev
```

### 日志管理

```bash
# 查看最近 100 行日志
docker logs --tail 100 skyrl-dev

# 实时查看日志
docker logs -f skyrl-dev

# 查看带时间戳的日志
docker logs -t skyrl-dev

# 查看最近 10 分钟的日志
docker logs --since 10m skyrl-dev
```

### 文件传输

```bash
# 从主机复制到容器
docker cp /path/on/host/file.py skyrl-dev:/workspace/

# 从容器复制到主机
docker cp skyrl-dev:/workspace/results.txt /path/on/host/

# 同步整个目录
docker cp /path/on/host/project/ skyrl-dev:/workspace/project/
```

## 环境变量配置

### 支持的环境变量

| 环境变量           | 默认值 | 说明                                       |
| ------------------ | ------ | ------------------------------------------ |
| `SSH_ENABLE`       | `1`    | 是否启用 SSH（0=禁用，1=启用）             |
| `SSH_PORT`         | `22`   | SSH 服务端口                               |
| `JUPYTER_PASSWORD` | 无     | Jupyter Lab 密码（不设置则不启动 Jupyter） |
| `JUPYTER_PORT`     | `8888` | Jupyter Lab 端口                           |

### 完整配置示例

```bash
docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  --restart unless-stopped \
  -v ~/workspace:/workspace \
  -v ~/datasets:/datasets:ro \
  -v ~/models:/models \
  -p 8265:8265 \
  -p 6379:6379 \
  -p 8888:8888 \
  -p 22:22 \
  -e SSH_ENABLE=1 \
  -e SSH_PORT=22 \
  -e JUPYTER_PASSWORD="your-secure-password" \
  -e JUPYTER_PORT=8888 \
  -e RAY_DASHBOARD_HOST=0.0.0.0 \
  yottalabsai/skyrl-yotta:latest
```

## Ray Dashboard 访问

### 本地访问

启动容器后，在浏览器中访问：

```
http://localhost:8265
```

### 在容器内检查 Ray 状态

```bash
# 进入容器
docker exec -it skyrl-dev bash

# 检查 Ray 是否运行
ray status

# 手动启动 Ray（如果未运行）
ray start --head --dashboard-host=0.0.0.0 --dashboard-port=8265

# 停止 Ray
ray stop
```

## 多 GPU 分布式训练

### 单机多卡（推荐配置）

```bash
docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  --restart unless-stopped \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  yottalabsai/skyrl-yotta:latest
```

### 多节点集群部署

#### Head 节点

```bash
docker run --gpus all -d \
  --name skyrl-head \
  --shm-size=32g \
  --network host \
  -v ~/workspace:/workspace \
  -e RAY_HEAD_SERVICE_HOST=0.0.0.0 \
  yottalabsai/skyrl-yotta:latest
```

#### Worker 节点

```bash
# 在其他机器上运行
docker run --gpus all -d \
  --name skyrl-worker \
  --shm-size=32g \
  --network host \
  -v ~/workspace:/workspace \
  -e RAY_ADDRESS="<head-node-ip>:6379" \
  yottalabsai/skyrl-yotta:latest
```

## 训练示例

### 简单 PPO 训练示例

创建训练脚本：

```python
# train_cartpole.py
import ray
from ray.rllib.algorithms.ppo import PPOConfig

# 初始化 Ray
ray.init(ignore_reinit_error=True)

# 配置 PPO 算法
config = (
    PPOConfig()
    .environment("CartPole-v1")
    .framework("torch")
    .resources(num_gpus=1)
    .rollouts(num_rollout_workers=4)
    .training(
        train_batch_size=4000,
        sgd_minibatch_size=128,
        num_sgd_iter=30,
    )
)

# 创建算法实例
algo = config.build()

# 训练 10 轮
print("\nStarting training...")
for i in range(10):
    result = algo.train()
    print(f"Iteration {i+1}: reward={result['episode_reward_mean']:.2f}")

# 保存模型
checkpoint_dir = algo.save("/workspace/models/cartpole_ppo")
print(f"\n✓ Model saved to: {checkpoint_dir}")

# 清理资源
algo.stop()
ray.shutdown()

print("✓ Training completed!")
```

### 运行训练

```bash
# 在容器内运行
python /workspace/train_cartpole.py

# 或从主机运行
docker exec -it skyrl-dev python /workspace/train_cartpole.py
```

### 多 GPU 训练示例

```python
# train_multi_gpu.py
import ray
from ray.rllib.algorithms.ppo import PPOConfig

# 初始化 Ray（使用所有 GPU）
ray.init(ignore_reinit_error=True)

# 配置多 GPU 训练
config = (
    PPOConfig()
    .environment("CartPole-v1")
    .framework("torch")
    .resources(
        num_gpus=4,  # 使用 4 个 GPU
        num_cpus_per_worker=2,
    )
    .rollouts(
        num_rollout_workers=16,  # 16 个 worker
    )
    .training(
        train_batch_size=16000,
        sgd_minibatch_size=512,
    )
)

algo = config.build()

# 训练
for i in range(50):
    result = algo.train()
    if i % 5 == 0:
        print(f"Iteration {i}: reward={result['episode_reward_mean']:.2f}")
        algo.save(f"/workspace/models/cartpole_multi_gpu_iter_{i}")

algo.stop()
ray.shutdown()
```

## SSH 访问配置

### 方法 1：使用 SSH 密钥（推荐）

#### 1. 生成 SSH 密钥对（在主机上）

```bash
ssh-keygen -t ed25519 -f ~/.ssh/skyrl_key -N ""
```

#### 2. 添加公钥到容器

```bash
# 创建 .ssh 目录
docker exec skyrl-dev mkdir -p /root/.ssh

# 复制公钥
docker cp ~/.ssh/skyrl_key.pub skyrl-dev:/root/.ssh/authorized_keys

# 设置权限
docker exec skyrl-dev chmod 700 /root/.ssh
docker exec skyrl-dev chmod 600 /root/.ssh/authorized_keys
```

#### 3. SSH 连接

```bash
ssh -i ~/.ssh/skyrl_key -p 22 root@localhost
```

### 方法 2：配置 SSH config（推荐）

创建或编辑 `~/.ssh/config`：

```bash
cat >> ~/.ssh/config << 'EOF'

# SkyRL Container
Host skyrl
    HostName localhost
    Port 22
    User root
    IdentityFile ~/.ssh/skyrl_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
```

然后直接连接：

```bash
ssh skyrl
```

### 方法 3：VS Code Remote SSH

1. 安装 VS Code 扩展：`Remote - SSH`
2. 按 `F1`，选择 `Remote-SSH: Connect to Host...`
3. 选择 `skyrl`（如果配置了 SSH config）
4. 或输入：`ssh -i ~/.ssh/skyrl_key root@localhost`

## 常见问题

### 1. Ray 警告 `/dev/shm` 空间不足

**问题**：
```
WARNING: The object store is using /tmp instead of /dev/shm
because /dev/shm has only 67108864 bytes available.
```

**解决方案**：
```bash
# 重启容器时增加 shm-size
docker rm -f skyrl-dev

docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  yottalabsai/skyrl-yotta:latest
```

**推荐 shm-size**：
- 小规模训练：`--shm-size=8g`
- 中规模训练：`--shm-size=16g`
- 大规模训练：`--shm-size=32g` 或更多

### 2. 容器启动后立即退出

**检查日志**：
```bash
docker logs skyrl-dev
```

**常见原因和解决方案**：

- **Nginx 未安装**：已在 Dockerfile 中修复
- **start.sh 执行失败**：检查日志中的错误信息
- **权限问题**：确保挂载的目录有正确的权限

### 3. GPU 未识别

**检查 NVIDIA 驱动**：
```bash
# 在主机上检查
nvidia-smi

# 检查 Docker GPU 支持
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

**安装 NVIDIA Container Toolkit**：

Ubuntu/Debian:
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 4. 端口冲突

**检查端口占用**：
```bash
# 检查 8265 端口
sudo lsof -i :8265
# 或
sudo netstat -tulpn | grep 8265
```

**使用不同端口**：
```bash
docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  -v ~/workspace:/workspace \
  -p 18265:8265 \
  -p 16379:6379 \
  -p 18888:8888 \
  -p 2222:22 \
  yottalabsai/skyrl-yotta:latest
```

### 5. 权限问题

**容器内文件权限错误**：
```bash
# 在容器内更改所有权
docker exec skyrl-dev chown -R root:root /workspace

# 或在启动时使用用户映射
docker run --gpus all -d \
  --name skyrl-dev \
  --user $(id -u):$(id -g) \
  -v ~/workspace:/workspace \
  ...
```

## 性能优化

### 1. 增加共享内存

```bash
# 大规模训练推荐 32GB+
--shm-size=32g

# 或使用主机的 /dev/shm
-v /dev/shm:/dev/shm
```

### 2. 使用主机网络（多节点训练）

```bash
# 减少网络开销
--network host
```

### 3. CPU 亲和性

```bash
# 绑定到特定 CPU 核心
--cpuset-cpus="0-63"

# 绑定到特定 NUMA 节点
--cpuset-mems="0"
```

### 4. 内存限制

```bash
# 限制最大内存使用
--memory=256g
--memory-swap=256g
```

### 5. GPU 选择

```bash
# 只使用特定 GPU
--gpus '"device=0,1,2,3"'

# 使用前 4 个 GPU
--gpus 4
```

## 监控和日志

### 实时监控

```bash
# 监控单个容器资源使用
docker stats skyrl-dev

# 监控所有 SkyRL 容器
docker stats $(docker ps --format '{{.Names}}' | grep skyrl)

# 持续监控并显示详细信息
watch -n 1 'docker stats --no-stream skyrl-dev'
```

### 日志配置

在启动时配置日志大小限制：

```bash
docker run --gpus all -d \
  --name skyrl-dev \
  --log-driver json-file \
  --log-opt max-size=100m \
  --log-opt max-file=3 \
  --shm-size=32g \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  yottalabsai/skyrl-yotta:latest
```

### 导出日志

```bash
# 导出到文件
docker logs skyrl-dev > skyrl-dev.log 2>&1

# 导出最近 1000 行
docker logs --tail 1000 skyrl-dev > skyrl-dev-recent.log 2>&1

# 按时间导出
docker logs --since "2026-01-15T08:00:00" skyrl-dev > skyrl-dev-today.log 2>&1
```

## 清理和维护

### 清理容器

```bash
# 停止并删除容器
docker rm -f skyrl-dev

# 删除所有停止的容器
docker container prune -f

# 删除所有 SkyRL 相关容器
docker ps -a | grep skyrl | awk '{print $1}' | xargs docker rm -f
```

### 清理镜像

```bash
# 清理悬空镜像
docker image prune -f

# 清理所有未使用的镜像
docker image prune -a -f

# 清理特定镜像
docker rmi yottalabsai/skyrl-yotta:latest
```

### 完整清理

```bash
# 清理所有未使用的资源
docker system prune -a -f --volumes

# 查看磁盘使用
docker system df

# 查看详细信息
docker system df -v
```

## Docker Compose 部署

### 单节点配置

创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  skyrl:
    image: yottalabsai/skyrl-yotta:latest
    container_name: skyrl-prod
    restart: unless-stopped
    
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    
    shm_size: 32gb
    
    volumes:
      - ~/workspace:/workspace
      - ~/datasets:/datasets:ro
      - ~/models:/models
    
    ports:
      - "8265:8265"
      - "6379:6379"
      - "8888:8888"
      - "2222:22"
    
    environment:
      - SSH_ENABLE=1
      - JUPYTER_PASSWORD=your-secure-password
      - TZ=Asia/Shanghai
    
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
```

### 多节点配置

创建 `docker-compose-cluster.yml`：

```yaml
version: '3.8'

services:
  skyrl-head:
    image: yottalabsai/skyrl-yotta:latest
    container_name: skyrl-head
    restart: unless-stopped
    network_mode: host
    
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    
    shm_size: 32gb
    
    volumes:
      - ~/workspace:/workspace
      - ~/datasets:/datasets:ro
      - ~/models:/models
    
    environment:
      - SSH_ENABLE=1
      - RAY_HEAD_SERVICE_HOST=0.0.0.0
      - TZ=Asia/Shanghai

  skyrl-worker:
    image: yottalabsai/skyrl-yotta:latest
    container_name: skyrl
