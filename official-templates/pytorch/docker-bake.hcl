variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026010901" }

group "default" {
  targets = ["pytorch290"]
}

# 你也可以继续叫 cuda；但建议以后改成 gpu（不绑定实现）
group "cuda" {
  targets   = ["pytorch290"]
  platforms = ["linux/amd64"]
}

# 1) GPU runtime（实现层，可替换 CUDA/ROCm/CPU-only）
target "gpu-runtime" {
  platforms  = ["linux/amd64"]
  dockerfile = "gpu-runtime.Dockerfile"
  context    = "."

  tags = [
    "${PUBLISHER}/gpu-runtime:${TAG_SUFFIX}"
  ]

  args = {
    BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
  }
}

# 2) OS base（语言无关）
target "os-base" {
  platforms  = ["linux/amd64"]
  dockerfile = "os-base.Dockerfile"
  context    = "."

  tags = [
    "${PUBLISHER}/os-base:${TAG_SUFFIX}"
  ]

  contexts = {
    base = "target:gpu-runtime"
  }

  args = {
    BASE_IMAGE = "base"
  }
}

# 3) Python runtime（源码编译 Python + pip/uv/conda 都应该在这层）
target "python-runtime" {
  platforms  = ["linux/amd64"]
  dockerfile = "python-runtime.Dockerfile"
  context    = "."

  tags = [
    "${PUBLISHER}/python-runtime:py3.11-${TAG_SUFFIX}"
  ]

  contexts = {
    base = "target:os-base"
  }

  args = {
    BASE_IMAGE     = "base"
    PYTHON_VERSION = "3.11.14"
  }
}

# 4) ML runtime（PyTorch/Jupyter/NCCL tests）
target "ml-runtime" {
  platforms  = ["linux/amd64"]
  dockerfile = "ml-runtime.Dockerfile"
  context    = "."

  tags = [
    "${PUBLISHER}/ml-runtime:pytorch2.9.0-${TAG_SUFFIX}"
  ]

  contexts = {
    base = "target:python-runtime"
  }

  args = {
    BASE_IMAGE         = "base"
    TORCH              = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
    NCCL_TESTS_VERSION = "v2.13.11"
  }
}

# 5) 最终镜像：runtime/service layer（SSH/nginx/start.sh/branding）
target "pytorch290" {
  platforms  = ["linux/amd64"]
  dockerfile = "runtime.Dockerfile"
  context    = "."

  tags = [
    # 建议带 TAG_SUFFIX，避免每次 push 覆盖同一个 tag
    "${PUBLISHER}/pytorch:2.9.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"
  ]

  contexts = {
    # pytorch 镜像必须基于 ml-runtime
    base    = "target:ml-runtime"
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE = "base"
  }
}
