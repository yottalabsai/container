# SkyRL Reinforcement Learning Container

### A GPU-accelerated runtime for reinforcement learning, designed for scalable policy optimization and RL experimentation.

YottaLabs AI - SkyRL Training Platform

Built on the official `skypilot/skypilot` image, with Ray, Gymnasium, SSH, Nginx, and other tools integrated into a reinforcement learning training environment.

## Quick Start

### 1. Build the image

```bash
cd official-templates/skyrl
docker buildx bake skyrl --no-cache --push
```

### 2. Start the container (recommended configuration)

```bash
# Remove old container (if it exists)
docker rm -f skyrl-dev

# Start the container
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

### 3. Check container status

```bash
# Check running status
docker ps | grep skyrl-dev

# View startup logs
docker logs skyrl-dev

# Follow live logs
docker logs -f skyrl-dev
```

### 4. Enter the container

```bash
docker exec -it skyrl-dev bash
```

## Verify components

### Quick verification of all components

```bash
# Save as /workspace/test_skyrl.sh
cat > /workspace/test_skyrl.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "Testing SkyRL Container"
echo "=========================================="

# 1. Check Nginx
echo -e "\n1. Nginx Status:"
service nginx status && echo "✓ Nginx OK" || echo "✗ Nginx failed"

# 2. Check SSH
echo -e "\n2. SSH Status:"
pgrep -x sshd && echo "✓ SSH OK" || echo "✗ SSH failed"

# 3. Check Branding
echo -e "\n3. Yotta Branding:"
cat /etc/yotta.txt

# 4. Check GPU
echo -e "\n4. GPU Status:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader && echo "✓ GPU OK" || echo "✗ GPU failed"

# 5. Test Ray
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

# 6. Test Gymnasium
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

### Verify individual components

#### Verify Nginx

```bash
service nginx status
# or
curl -I http://localhost
```

#### Verify SSH

```bash
ps aux | grep sshd
```

#### Verify GPU

```bash
nvidia-smi
```

#### Verify Ray

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

#### Verify Gymnasium

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

## Common commands

### Container management

```bash
# Stop the container
docker stop skyrl-dev

# Start the container
docker start skyrl-dev

# Restart the container
docker restart skyrl-dev

# Remove the container
docker rm -f skyrl-dev

# View container resource usage
docker stats skyrl-dev

# View container details
docker inspect skyrl-dev

# View port mappings
docker port skyrl-dev
```

### Log management

```bash
# View last 100 lines of logs
docker logs --tail 100 skyrl-dev

# Follow live logs
docker logs -f skyrl-dev

# View logs with timestamps
docker logs -t skyrl-dev

# View logs from the last 10 minutes
docker logs --since 10m skyrl-dev
```

### File transfer

```bash
# Copy from host to container
docker cp /path/on/host/file.py skyrl-dev:/workspace/

# Copy from container to host
docker cp skyrl-dev:/workspace/results.txt /path/on/host/

# Sync an entire directory
docker cp /path/on/host/project/ skyrl-dev:/workspace/project/
```

## Environment variables

### Supported environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_ENABLE` | `1` | Enable SSH (0=disabled, 1=enabled) |
| `SSH_PORT` | `22` | SSH service port |
| `JUPYTER_PASSWORD` | — | JupyterLab password (JupyterLab does not start if unset) |
| `JUPYTER_PORT` | `8888` | JupyterLab port |

### Full configuration example

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

## Ray Dashboard

### Local access

After starting the container, open in your browser:

```
http://localhost:8265
```

### Check Ray status inside the container

```bash
# Enter the container
docker exec -it skyrl-dev bash

# Check if Ray is running
ray status

# Start Ray manually (if not running)
ray start --head --dashboard-host=0.0.0.0 --dashboard-port=8265

# Stop Ray
ray stop
```

## Multi-GPU distributed training

### Single node, multiple GPUs (recommended)

```bash
docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  --restart unless-stopped \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  yottalabsai/skyrl-yotta:latest
```

### Multi-node cluster

#### Head node

```bash
docker run --gpus all -d \
  --name skyrl-head \
  --shm-size=32g \
  --network host \
  -v ~/workspace:/workspace \
  -e RAY_HEAD_SERVICE_HOST=0.0.0.0 \
  yottalabsai/skyrl-yotta:latest
```

#### Worker node

```bash
# Run on another machine
docker run --gpus all -d \
  --name skyrl-worker \
  --shm-size=32g \
  --network host \
  -v ~/workspace:/workspace \
  -e RAY_ADDRESS="<head-node-ip>:6379" \
  yottalabsai/skyrl-yotta:latest
```

## Training examples

### Simple PPO training example

Create a training script:

```python
# train_cartpole.py
import ray
from ray.rllib.algorithms.ppo import PPOConfig

# Initialize Ray
ray.init(ignore_reinit_error=True)

# Configure PPO algorithm
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

# Build the algorithm
algo = config.build()

# Train for 10 iterations
print("\nStarting training...")
for i in range(10):
    result = algo.train()
    print(f"Iteration {i+1}: reward={result['episode_reward_mean']:.2f}")

# Save the model
checkpoint_dir = algo.save("/workspace/models/cartpole_ppo")
print(f"\n✓ Model saved to: {checkpoint_dir}")

# Clean up
algo.stop()
ray.shutdown()

print("✓ Training completed!")
```

### Run training

```bash
# Inside the container
python /workspace/train_cartpole.py

# Or from the host
docker exec -it skyrl-dev python /workspace/train_cartpole.py
```

### Multi-GPU training example

```python
# train_multi_gpu.py
import ray
from ray.rllib.algorithms.ppo import PPOConfig

# Initialize Ray (use all GPUs)
ray.init(ignore_reinit_error=True)

# Configure multi-GPU training
config = (
    PPOConfig()
    .environment("CartPole-v1")
    .framework("torch")
    .resources(
        num_gpus=4,  # Use 4 GPUs
        num_cpus_per_worker=2,
    )
    .rollouts(
        num_rollout_workers=16,  # 16 workers
    )
    .training(
        train_batch_size=16000,
        sgd_minibatch_size=512,
    )
)

algo = config.build()

# Train
for i in range(50):
    result = algo.train()
    if i % 5 == 0:
        print(f"Iteration {i}: reward={result['episode_reward_mean']:.2f}")
        algo.save(f"/workspace/models/cartpole_multi_gpu_iter_{i}")

algo.stop()
ray.shutdown()
```

## SSH access

### Method 1: SSH key (recommended)

#### 1. Generate an SSH key pair (on the host)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/skyrl_key -N ""
```

#### 2. Add the public key to the container

```bash
# Create .ssh directory
docker exec skyrl-dev mkdir -p /root/.ssh

# Copy public key
docker cp ~/.ssh/skyrl_key.pub skyrl-dev:/root/.ssh/authorized_keys

# Set permissions
docker exec skyrl-dev chmod 700 /root/.ssh
docker exec skyrl-dev chmod 600 /root/.ssh/authorized_keys
```

#### 3. Connect via SSH

```bash
ssh -i ~/.ssh/skyrl_key -p 22 root@localhost
```

### Method 2: SSH config (recommended)

Create or edit `~/.ssh/config`:

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

Then connect directly:

```bash
ssh skyrl
```

### Method 3: VS Code Remote SSH

1. Install the VS Code extension: `Remote - SSH`
2. Press `F1`, select `Remote-SSH: Connect to Host...`
3. Select `skyrl` (if you configured SSH config)
4. Or enter: `ssh -i ~/.ssh/skyrl_key root@localhost`

## Troubleshooting

### 1. Ray warning: insufficient `/dev/shm` space

**Problem**:
```
WARNING: The object store is using /tmp instead of /dev/shm
because /dev/shm has only 67108864 bytes available.
```

**Solution**:
```bash
# Restart the container with a larger shm-size
docker rm -f skyrl-dev

docker run --gpus all -d \
  --name skyrl-dev \
  --shm-size=32g \
  -v ~/workspace:/workspace \
  -p 8265:8265 \
  yottalabsai/skyrl-yotta:latest
```

**Recommended shm-size**:
- Small-scale training: `--shm-size=8g`
- Medium-scale training: `--shm-size=16g`
- Large-scale training: `--shm-size=32g` or more

### 2. Container exits immediately after starting

**Check the logs**:
```bash
docker logs skyrl-dev
```

**Common causes and solutions**:

- **Nginx not installed**: Fixed in the Dockerfile
- **start.sh failed**: Check the error message in the logs
- **Permission issues**: Ensure mounted directories have correct permissions

### 3. GPU not detected

**Check NVIDIA drivers**:
```bash
# Check on the host
nvidia-smi

# Check Docker GPU support
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

**Install NVIDIA Container Toolkit**:

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

### 4. Port conflict

**Check port usage**:
```bash
# Check port 8265
sudo lsof -i :8265
# or
sudo netstat -tulpn | grep 8265
```

**Use different ports**:
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

### 5. Permission issues

**File permission errors inside the container**:
```bash
# Change ownership inside the container
docker exec skyrl-dev chown -R root:root /workspace

# Or use user mapping at startup
docker run --gpus all -d \
  --name skyrl-dev \
  --user $(id -u):$(id -g) \
  -v ~/workspace:/workspace \
  ...
```

## Performance tuning

### 1. Increase shared memory

```bash
# Recommended 32GB+ for large-scale training
--shm-size=32g

# Or mount the host /dev/shm
-v /dev/shm:/dev/shm
```

### 2. Use host networking (multi-node training)

```bash
# Reduce network overhead
--network host
```

### 3. CPU affinity

```bash
# Pin to specific CPU cores
--cpuset-cpus="0-63"

# Pin to specific NUMA node
--cpuset-mems="0"
```

### 4. Memory limits

```bash
# Limit maximum memory usage
--memory=256g
--memory-swap=256g
```

### 5. GPU selection

```bash
# Use specific GPUs
--gpus '"device=0,1,2,3"'

# Use first 4 GPUs
--gpus 4
```

## Monitoring and logs

### Real-time monitoring

```bash
# Monitor a single container's resource usage
docker stats skyrl-dev

# Monitor all SkyRL containers
docker stats $(docker ps --format '{{.Names}}' | grep skyrl)

# Continuous monitoring with details
watch -n 1 'docker stats --no-stream skyrl-dev'
```

### Log configuration

Configure log size limits at startup:

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

### Export logs

```bash
# Export to file
docker logs skyrl-dev > skyrl-dev.log 2>&1

# Export last 1000 lines
docker logs --tail 1000 skyrl-dev > skyrl-dev-recent.log 2>&1

# Export by time
docker logs --since "2026-01-15T08:00:00" skyrl-dev > skyrl-dev-today.log 2>&1
```

## Cleanup and maintenance

### Remove containers

```bash
# Stop and remove the container
docker rm -f skyrl-dev

# Remove all stopped containers
docker container prune -f

# Remove all SkyRL-related containers
docker ps -a | grep skyrl | awk '{print $1}' | xargs docker rm -f
```

### Remove images

```bash
# Remove dangling images
docker image prune -f

# Remove all unused images
docker image prune -a -f

# Remove a specific image
docker rmi yottalabsai/skyrl-yotta:latest
```

### Full cleanup

```bash
# Remove all unused resources
docker system prune -a -f --volumes

# View disk usage
docker system df

# View detailed usage
docker system df -v
```

## Docker Compose

### Single-node configuration

Create `docker-compose.yml`:

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

    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
```

### Multi-node configuration

Create `docker-compose-cluster.yml`:

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

  skyrl-worker:
    image: yottalabsai/skyrl-yotta:latest
    container_name: skyrl-worker
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

    environment:
      - RAY_ADDRESS="skyrl-head:6379"
```
