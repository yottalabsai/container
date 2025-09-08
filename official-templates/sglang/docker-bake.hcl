variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025090201" }

group "cuda" {
    targets = [
        "280-py311-cuda1281-cudnn-devel-ubuntu2204",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
}


target "sglang" {
    platform = ["linux/amd64", "linux/arm64"]
    dockerfile = "Dockerfile"
    tags = ["${PUBLISHER}/pytorch:sglang-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"]
    contexts = {
        scripts = "../../container-template"
        proxy = "../../container-template/proxy"
        logo = "../../container-template"
    }
    args = {
        BASE_IMAGE                 = "nvidia/cuda:12.1.1-cudnn-devel-ubuntu22.04"
        PYTHON_VERSION             = "3.11"
        TORCH                      = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
        TORCH_CUDA_ARCH_LIST       = "9.0"
        CMAKE_BUILD_PARALLEL_LEVEL = "8"

        PIP_DISABLE_PIP_VERSION_CHECK = "1"
        PYTHONUNBUFFERED              = "1"
        HF_HOME                       = "/workspace/hf"
        HF_HUB_ENABLE_HF_TRANSFER     = "1"
        SGLANG_MODEL                  = "Qwen/Qwen2.5-7B-Instruct"
        SGLANG_HOST                   = "0.0.0.0"
        SGLANG_PORT                   = "30000"
        SGLANG_EXTRA                  = ""
        CCACHE_DIR                    = "/root/.ccache"
        CCACHE_COMPRESS               = "1"
        CCACHE_MAXSIZE                = "10G"
    }
}
