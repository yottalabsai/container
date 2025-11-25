variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

variable "BASE_IMAGE" { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER" { default = "3.11" }
variable "COMFY_PORT" { default = "8188" }

variable "TORCH_VERSION"        { default = "2.4.1" }
variable "TORCH_VISION_VERSION" { default = "0.19.1" }
variable "TORCH_CUDA"           { default = "cu124" }

group "default"      { targets = ["flux1dev-comfyui"] }
group "flux1dev-all" { targets = ["flux1dev-comfyui", "flux1dev-comfyui-nunchaku"] }

# ---- 标准版（不装 Nunchaku）----
target "flux1dev-comfyui" {
  description = "ComfyUI + Flux1-Dev 环境镜像"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/flux1.dev:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    # 当前目录为 main context
    # scripts/proxy/logo 是额外 context，用于 COPY --from=<name>
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
  }
}

# ---- Nunchaku 版 ----
target "flux1dev-comfyui-nunchaku" {
  description = "ComfyUI + Flux1-Dev + Nunchaku 变体"
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
  }
}
