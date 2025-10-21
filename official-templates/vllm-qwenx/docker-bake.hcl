variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

group "cuda" {
    targets = [
        "vllm-qwenx",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}


target "vllm-qwenx" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION = "3.11"
        TORCH = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
        VLLM_MODEL     = "Qwen/Qwen2.5-7B-Instruct"
        VLLM_EXTRA     = ""
        VLLM_HOST      = "0.0.0.0"
        VLLM_PORT      = "8000"
        INSTALL_FLASHINFER="0"
    }
}
