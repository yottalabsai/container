# ==============================
# Unsloth LLM Fine-tuning 镜像构建
# ==============================

variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025122201" }

variable "BASE_IMAGE" { default = "nvidia/cuda:12.1.0-cudnn-runtime-ubuntu22.04" }
variable "PYTHON_VER" { default = "3.11" }

# 可选：如果你想把 Torch 也通过 bake 统一管控
variable "TORCH_VERSION"   { default = "2.4.1" }
variable "TORCH_CUDA"      { default = "cu121" }
variable "TORCH_INDEX_URL" { default = "https://download.pytorch.org/whl/cu121" }

# 组：
# - default：只构建 Unsloth 基础镜像
group "default" {
  targets = ["unsloth"]
}

# ==============================
# Unsloth - 基础版
# ==============================
target "unsloth" {
  description = "Unsloth LLM fine-tuning base image"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/unsloth:cuda12.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  # 和 Wan2.2 一样的上下文映射
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    # 和 Dockerfile 里的 ARG 名字对应
    BASE_IMAGE     = BASE_IMAGE
    PYTHON_VERSION = PYTHON_VER
    UBUNTU_USER    = "ubuntu"

    # 如果你在 Dockerfile 里加了这些 ARG，就可以透传进去
    TORCH_VERSION   = TORCH_VERSION
    TORCH_CUDA      = TORCH_CUDA
    TORCH_INDEX_URL = TORCH_INDEX_URL
  }
}
