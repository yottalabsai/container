variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2026012201" }

group "default" {
  targets = ["comfyui-nunchaku"]
}

group "cuda" {
  targets = ["comfyui-nunchaku"]
  platforms = ["linux/amd64"]
}

target "comfyui-nunchaku" {
  dockerfile = "Dockerfile"
  tags = ["${PUBLISHER}/comfyui-nunchaku:cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"]
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
  args = {
    BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11"

    # NOTE: using nightly may make Nunchaku backend wheels harder to match.
    # Prefer stable torch builds when possible.
    TORCH = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128"

    COMFYUI_HOST="0.0.0.0"
    COMFYUI_PORT="8188"
    COMFYUI_EXTRA_ARGS=""
  }
}
