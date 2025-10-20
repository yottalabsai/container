variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default" { targets = ["wan21-comfyui"] }
group "comfy-all" { targets = ["wan21-comfyui", "wan21-comfyui-nunchaku"] }

# ---- 标准版（无 Nunchaku）----
target "wan21-comfyui" {
  description = "ComfyUI + WAN 2.1 环境镜像"
  dockerfile  = "Dockerfile.comfyui"
  platforms   = ["linux/amd64", "linux/arm64"]
  tags = [
    "${PUBLISHER}/wan2.1:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  args = {
    BASE_IMAGE       = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION   = "3.11"
    COMFYUI_PORT     = "8188"
    INSTALL_NUNCHAKU = "false"
  }
}

# ---- Nunchaku 版（需要传入 NUNCHAKU_REPO）----
target "wan21-comfyui-nunchaku" {
  description = "ComfyUI + WAN 2.1 + Nunchaku 变体"
  dockerfile  = "Dockerfile.comfyui"
  platforms   = ["linux/amd64", "linux/arm64"]
  tags = [
    "${PUBLISHER}/wan2.1:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  args = {
    BASE_IMAGE       = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION   = "3.11"
    COMFYUI_PORT     = "8188"
    INSTALL_NUNCHAKU = "true"
    NUNCHAKU_REPO    = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF     = "main"
  }
}