## AWS Neuron — Docker Template

Container image for AWS Inferentia2 (inf2) and Trainium (trn1/trn2) hardware.

### What's included

- Python 3.11
- torch-neuronx, torchvision, torchaudio (Neuron pip repo)
- neuronx-cc (Neuron compiler)
- transformers-neuronx, neuronx-distributed
- transformers, datasets, huggingface_hub, accelerate
- JupyterLab, ipywidgets, jupyter-archive
- AWS Neuron runtime APT packages: `aws-neuronx-tools`, `aws-neuronx-runtime-lib`, `aws-neuronx-collectives`
- SSH, nginx, standard CLI tools

---

## Host Prerequisites (EC2 only)

The **Neuron kernel driver** (`aws-neuronx-dkms`) must be installed on the EC2 host — the container only ships the runtime library, not the kernel module.

```bash
# Amazon Linux 2023
sudo tee /etc/yum.repos.d/neuron.repo > /dev/null <<'EOF'
[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
metadata_expire=0
EOF
sudo rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB
sudo yum install -y aws-neuronx-dkms
```

Verify Neuron devices are visible on the host:

```bash
ls /dev/neuron*
# trn1.2xlarge  → /dev/neuron0
# trn1.32xlarge → /dev/neuron0 … /dev/neuron15
```

---

## Running the Container

```bash
docker run -d \
  --device /dev/neuron0 \
  -e PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -e JUPYTER_PASSWORD=ubuntu \
  -p 8888:8888 \
  -p 2222:22 \
  -p 8080:80 \
  --name aws-neuron \
  yottalabsai/aws-neuron:py3.11-ubuntu22.04-<tag>
```

Add `--device /dev/neuron1`, `--device /dev/neuron2`, … for multi-chip instances.

| Service  | Port |
|----------|------|
| JupyterLab | 8888 |
| SSH        | 22   |
| nginx      | 80   |

---

## Smoke Tests

```bash
IMAGE="yottalabsai/aws-neuron:py3.11-ubuntu22.04-<tag>"

# List Neuron devices
docker run --rm --device /dev/neuron0 $IMAGE /opt/aws/neuron/bin/neuron-ls

# Verify torch-neuronx
docker run --rm --device /dev/neuron0 $IMAGE \
  python3.11 -c "import torch_neuronx; print(torch_neuronx.__version__)"

# Verify neuronx-cc (compiler)
docker run --rm --device /dev/neuron0 $IMAGE /opt/aws/neuron/bin/neuronx-cc --version
```

Minimal compile-and-run test (inside the container or via `docker exec`):

```python
import torch
import torch_neuronx

model = torch.nn.Linear(4, 2)
example = torch.randn(1, 4)
traced = torch_neuronx.trace(model, example)
print(traced(example))  # runs on NeuronCore
```

> **Common gotcha**: `RuntimeError: No Neuron devices found` means either the host driver is not installed or `--device /dev/neuron0` was omitted from the `docker run` command.

---

## Build Instructions

```bash
cd official-templates/aws-neuron
docker buildx bake
```

To override versions:

```bash
docker buildx bake \
  --set aws-neuron.args.TORCH_NEURONX_VERSION=2.1.* \
  --set aws-neuron.args.NEURONX_CC_VERSION=2.14.*
```

## Exposed Ports

- 22/tcp (SSH)
- 80/tcp (nginx)
- 8888/tcp (JupyterLab)
