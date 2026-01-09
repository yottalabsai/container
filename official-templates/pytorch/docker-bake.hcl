variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025101701" }

group "cuda" {
    targets = [
        "pytorch280",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}


target "pytorch280" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/jupyter:pytorch-2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04-${TAG_SUFFIX}"]
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
