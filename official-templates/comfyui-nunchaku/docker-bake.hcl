variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025090901" }

group "cuda" {
    targets = [
        "280-py311-cuda1281-cudnn-devel-ubuntu2204",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}


target "comfyui-nunchaku" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/pytorch:comfyui-nunchaku-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION = "3.11"
        TORCH = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
        COMFYUI_HOST="0.0.0.0"
        COMFYUI_PORT="8188"
        COMFYUI_EXTRA_ARGS=""
    }
}
