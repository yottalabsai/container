# ==============================
# Wan2.2-Animate-14B ComfyUI 镜像构建
# ==============================

variable "PUBLISHER"   { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

variable "BASE_IMAGE"  { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER"  { default = "3.11" }
variable "COMFY_PORT"  { default = "8188" }

# Torch / CUDA
variable "TORCH_CHANNEL"            { default = "nightly" }
variable "TORCH_VERSION"            { default = "2.4.1" }
variable "TORCH_VISION_VERSION"     { default = "0.19.1" }
variable "TORCH_CUDA"               { default = "cu121" }
variable "TORCH_NIGHTLY_INDEX_URL"  { default = "https://download.pytorch.org/whl/nightly" }

# 组：
# - default：只构建标准版
# - wan22-all：标准 + Nunchaku
group "default"    { targets = ["wan22-comfyui"] }
group "wan22-all"  { targets = ["wan22-comfyui", "wan22-comfyui-nunchaku"] }

# ==============================
# Wan2.2-Animate-14B - 标准版
# ==============================
target "wan22-comfyui" {
  description = "ComfyUI + Wan2.2-Animate-14B"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.2:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = BASE_IMAGE
    PYTHON_VERSION = PYTHON_VER
    UBUNTU_USER    = "ubuntu"
    COMFYUI_PORT   = COMFY_PORT

    INSTALL_NUNCHAKU = "false"
    NUNCHAKU_REPO    = ""
    NUNCHAKU_REF     = ""

    TORCH_CHANNEL           = TORCH_CHANNEL
    TORCH_VERSION           = TORCH_VERSION
    TORCH_VISION_VERSION    = TORCH_VISION_VERSION
    TORCH_CUDA              = TORCH_CUDA
    TORCH_NIGHTLY_INDEX_URL = TORCH_NIGHTLY_INDEX_URL
  }
}

# ==============================
# Wan2.2-Animate-14B - Nunchaku 版
# ==============================
target "wan22-comfyui-nunchaku" {
  description = "ComfyUI + Wan2.2-Animate-14B + Nunchaku"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.2:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = BASE_IMAGE
    PYTHON_VERSION = PYTHON_VER
    UBUNTU_USER    = "ubuntu"
    COMFYUI_PORT   = COMFY_PORT

    INSTALL_NUNCHAKU = "true"
    NUNCHAKU_REPO    = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF     = "main"

    TORCH_CHANNEL           = TORCH_CHANNEL
    TORCH_VERSION           = TORCH_VERSION
    TORCH_VISION_VERSION    = TORCH_VISION_VERSION
    TORCH_CUDA              = TORCH_CUDA
    TORCH_NIGHTLY_INDEX_URL = TORCH_NIGHTLY_INDEX_URL
  }
}
