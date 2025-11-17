variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

variable "BASE_IMAGE"  { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER"  { default = "3.11" }
variable "COMFY_PORT"  { default = "8188" }

variable "TORCH_VERSION" { default = "2.4.0" }
variable "TORCH_CUDA"    { default = "cu124" }

group "default" { targets = ["wan21-comfyui"] }
group "comfy-all" { targets = ["wan21-comfyui", "wan21-comfyui-nunchaku"] }

# ---- 标准版（无 Nunchaku）----
target "wan21-comfyui" {
  description = "ComfyUI + WAN 2.1 环境镜像"
  dockerfile  = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
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

    TORCH_VERSION = TORCH_VERSION
    TORCH_CUDA    = TORCH_CUDA
  }
}

# ---- Nunchaku 版（需要传入 NUNCHAKU_REPO）----
target "wan21-comfyui-nunchaku" {
  description = "ComfyUI + WAN 2.1 + Nunchaku 变体"
  dockerfile  = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
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

    TORCH_VERSION = TORCH_VERSION
    TORCH_CUDA    = TORCH_CUDA
  }
}