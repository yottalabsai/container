variable "PUBLISHER" {
    default = "yottalabsai"
}


group "cuda" {
    targets = [
        "280-py311-cuda1281-cudnn-devel-ubuntu2204",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}


target "280-py311-cuda1281-cudnn-devel-ubuntu2204" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04-2025081803"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION = "3.11"
        TORCH = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
    }
}
