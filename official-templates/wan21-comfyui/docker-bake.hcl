# ==============================
# Wan2.1-T2V-1.3B ComfyUI 镜像构建
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
variable "TORCH_CUDA"               { default = "cu128" }
variable "TORCH_NIGHTLY_INDEX_URL"  { default = "https://download.pytorch.org/whl/nightly" }

# Wan2.1 模型下载参数
# 注意：现在默认不自动下载，Pod 启动时如需自动下载再通过环境变量覆盖
variable "WAN_ENABLE_DOWNLOAD"  { default = "false" }
variable "WAN_MODEL_ID"         { default = "Wan-AI/Wan2.1-T2V-1.3B" }
variable "HF_TOKEN"             { default = "" }

# 组：
# - default：只构建标准版
# - wan21-all：标准 + Nunchaku
group "default"    { targets = ["wan21-comfyui"] }
group "wan21-all"  { targets = ["wan21-comfyui", "wan21-comfyui-nunchaku"] }

# ==============================
# Wan2.1-T2V-1.3B - 标准版
# ==============================
target "wan21-comfyui" {
  description = "ComfyUI + Wan2.1-T2V-1.3B"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.1:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
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

    WAN_ENABLE_DOWNLOAD = WAN_ENABLE_DOWNLOAD
    WAN_MODEL_ID        = WAN_MODEL_ID
    HF_TOKEN            = "${HF_TOKEN}"
  }
}

# ==============================
# Wan2.1-T2V-1.3B - Nunchaku 版
# ==============================
target "wan21-comfyui-nunchaku" {
  description = "ComfyUI + Wan2.1-T2V-1.3B + Nunchaku"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.1:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
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

    WAN_ENABLE_DOWNLOAD = WAN_ENABLE_DOWNLOAD
    WAN_MODEL_ID        = WAN_MODEL_ID
    HF_TOKEN            = "${HF_TOKEN}"
  }
}
