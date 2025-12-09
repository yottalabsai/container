variable "PUBLISHER"   { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

variable "BASE_IMAGE"  { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER"  { default = "3.11" }
variable "COMFY_PORT"  { default = "8188" }

# Torch 相关
variable "TORCH_CHANNEL"           { default = "nightly" }
variable "TORCH_VERSION"           { default = "2.4.1" }
variable "TORCH_VISION_VERSION"    { default = "0.19.1" }
variable "TORCH_CUDA"              { default = "cu128" }
variable "TORCH_NIGHTLY_INDEX_URL" { default = "https://download.pytorch.org/whl/nightly" }

# 默认启用 VAE（运行时仍可用 ENABLE_FLUX_VAE 覆盖）
variable "ENABLE_FLUX_VAE" { default = "true" }

group "default"      { targets = ["flux1dev-comfyui"] }
group "flux1dev-all" { targets = ["flux1dev-comfyui", "flux1dev-comfyui-nunchaku"] }

# ---- 标准版（不装 Nunchaku）----
target "flux1dev-comfyui" {
  description = "ComfyUI + FLUX1-Dev 环境镜像"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/flux1.dev:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE           = BASE_IMAGE
    PYTHON_VERSION       = PYTHON_VER
    UBUNTU_USER          = "ubuntu"
    COMFYUI_PORT         = COMFY_PORT

    INSTALL_NUNCHAKU     = "false"
    NUNCHAKU_REPO        = ""
    NUNCHAKU_REF         = ""

    TORCH_CHANNEL        = TORCH_CHANNEL
    TORCH_VERSION        = TORCH_VERSION
    TORCH_VISION_VERSION = TORCH_VISION_VERSION
    TORCH_CUDA           = TORCH_CUDA
    TORCH_NIGHTLY_INDEX_URL = TORCH_NIGHTLY_INDEX_URL

    ENABLE_FLUX_VAE      = ENABLE_FLUX_VAE
  }
}

# ---- Nunchaku 版 ----
target "flux1dev-comfyui-nunchaku" {
  description = "ComfyUI + FLUX1-Dev + Nunchaku 变体"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/flux1.dev:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE           = BASE_IMAGE
    PYTHON_VERSION       = PYTHON_VER
    UBUNTU_USER          = "ubuntu"
    COMFYUI_PORT         = COMFY_PORT

    INSTALL_NUNCHAKU     = "true"
    NUNCHAKU_REPO        = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF         = "main"

    TORCH_CHANNEL        = TORCH_CHANNEL
    TORCH_VERSION        = TORCH_VERSION
    TORCH_VISION_VERSION = TORCH_VISION_VERSION
    TORCH_CUDA           = TORCH_CUDA
    TORCH_NIGHTLY_INDEX_URL = TORCH_NIGHTLY_INDEX_URL

    ENABLE_FLUX_VAE      = ENABLE_FLUX_VAE
  }
}
