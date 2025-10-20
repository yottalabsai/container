variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default"    { targets = ["flux1dev-comfyui"] }
group "flux1dev-all" { targets = ["flux1dev-comfyui", "flux1dev-comfyui-nunchaku"] }

# ---- 标准版（不装 Nunchaku）----
target "flux1dev-comfyui" {
  description = "ComfyUI + FLUX-1.dev 环境镜像"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64","linux/arm64"]
  tags = [
    "${PUBLISHER}/flux1.dev:comfyui-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  args = {
    PYTHON_VERSION    = "3.11"
    COMFYUI_PORT      = "8188"
    INSTALL_NUNCHAKU  = "false"
    # Nunchaku 相关留默认，不安装
    NUNCHAKU_REPO     = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF      = "main"
  }
}

# ---- Nunchaku 版（启用加速插件）----
target "flux1dev-comfyui-nunchaku" {
  description = "ComfyUI + FLUX-1.dev + Nunchaku"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64","linux/arm64"]
  tags = [
    "${PUBLISHER}/flux1.dev:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]
  args = {
    PYTHON_VERSION    = "3.11"
    COMFYUI_PORT      = "8188"
    INSTALL_NUNCHAKU  = "true"   # 启用 Nunchaku
    NUNCHAKU_REPO     = "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
    NUNCHAKU_REF      = "main"
  }
}