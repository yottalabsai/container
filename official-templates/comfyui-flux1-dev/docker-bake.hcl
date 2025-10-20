variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

target "comfyui-flux-1.dev" {
    platforms = ["linux/amd64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/pytorch:comfyui-flux-1.dev-${TAG_SUFFIX}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION = "3.10"
        TORCH = "torch torchvision --index-url https://download.pytorch.org/whl/cu121"
        COMFYUI_HOST = "0.0.0.0"
        COMFYUI_PORT = "8188"
        COMFYUI_EXTRA_ARGS = "--disable-auto-launch"
    }
}

group "default" {
    targets = [
        "comfyui-flux-1.dev",
    ]
}
