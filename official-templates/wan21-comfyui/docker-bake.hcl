variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

variable "BASE_IMAGE" { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER" { default = "3.11" }
variable "COMFY_PORT" { default = "8188" }

variable "TORCH_VERSION"        { default = "2.4.1" }
variable "TORCH_VISION_VERSION" { default = "0.19.1" }
variable "TORCH_CUDA"           { default = "cu124" }

# 如果 WAN21_MODEL_URL 非空 → build 时下载并 bake 进镜像
# 如果 还是空字符串 → build 时只打环境，不下模型
variable "WAN21_MODEL_URL"       { default = "https://huggingface.co/One-2-Flow/WAN2.1-Unet-XL/resolve/main/WAN2.1-Unet-XL.safetensors" }
variable "WAN21_MODEL_FILENAME"  { default = "wan2.1.safetensors" }
variable "WAN21_MODEL_SUBDIR"    { default = "ckpt" }

group "default" { targets = ["wan21-comfyui"] }
group "comfy-all" { targets = ["wan21-comfyui", "wan21-comfyui-nunchaku"] }

# ---- 标准版（无 Nunchaku）----
target "wan21-comfyui" {
  description = "ComfyUI + WAN 2.1 环境镜像"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.1:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
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

    TORCH_VERSION        = TORCH_VERSION
    TORCH_VISION_VERSION = TORCH_VISION_VERSION
    TORCH_CUDA           = TORCH_CUDA

    WAN21_MODEL_URL      = WAN21_MODEL_URL
    WAN21_MODEL_FILENAME = WAN21_MODEL_FILENAME
    WAN21_MODEL_SUBDIR   = WAN21_MODEL_SUBDIR
  }
}

# ---- Nunchaku 版 ----
target "wan21-comfyui-nunchaku" {
  description = "ComfyUI + WAN 2.1 + Nunchaku 变体"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/wan2.1:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
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

    TORCH_VERSION        = TORCH_VERSION
    TORCH_VISION_VERSION = TORCH_VISION_VERSION
    TORCH_CUDA           = TORCH_CUDA

    WAN21_MODEL_URL      = WAN21_MODEL_URL
    WAN21_MODEL_FILENAME = WAN21_MODEL_FILENAME
    WAN21_MODEL_SUBDIR   = WAN21_MODEL_SUBDIR
  }
}
