variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default" { targets = ["wan22-comfyui"] }
group "wan22-all" { targets = ["wan22-comfyui", "wan22-comfyui-nunchaku"] }

# ---- WAN 2.2 标准版 ----
target "wan22-comfyui" {
  description = "ComfyUI + WAN 2.2 环境镜像"
  dockerfile  = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [
    "${PUBLISHER}/wan2.2:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
  args = {
    PYTHON_VERSION   = "3.11"
    COMFYUI_PORT     = "8188"
    INSTALL_NUNCHAKU = "false"
  }
}

# ---- WAN 2.2 + Nunchaku 版 ----
target "wan22-comfyui-nunchaku" {
  description = "ComfyUI + WAN 2.2 + Nunchaku"
  dockerfile  = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [
    "${PUBLISHER}/wan2.2:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
  args = {
    PYTHON_VERSION   = "3.11"
    COMFYUI_PORT     = "8188"
    INSTALL_NUNCHAKU = "true"
    NUNCHAKU_REPO    = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF     = "main"
  }
}