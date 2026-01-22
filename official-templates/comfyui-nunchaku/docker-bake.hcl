variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

group "cuda" {
    targets = [
        "comfyui-nunchaku",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}

target "comfyui-nunchaku" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/comfyui-nunchaku:cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION = "3.11"

        # Recommend stable builds here if you want Nunchaku backend wheels to match torch.
        # If you really want nightly cu128, keep your existing line.
        TORCH = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"

        COMFYUI_HOST="0.0.0.0"
        COMFYUI_PORT="8188"
        COMFYUI_EXTRA_ARGS=""
    }
}
