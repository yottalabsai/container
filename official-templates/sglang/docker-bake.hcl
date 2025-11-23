variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025090901" }

# 默认就构建这个 sglang 镜像
group "default" {
  targets = ["sglang"]
}

# 需要的话可以再加一个分组，比如 cuda-all 之类
group "cuda" {
  targets = ["sglang"]
}

target "sglang" {
  description = "SGLang Runtime (CUDA 12.1.1 + PyTorch cu121)"
  dockerfile  = "Dockerfile"

  # CUDA 官方镜像通常只有 amd64，arm64 要单独处理，这里先只放 amd64
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/pytorch:sglang-cuda12.1.1-ubuntu22.04-${TAG_SUFFIX}"
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    # 对应 Dockerfile 顶部 ARG
    BASE_IMAGE     = "nvidia/cuda:12.1.1-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11"

    # 不传 TORCH = 走 Dockerfile 的“稳定 cu121”逻辑
    # 需要 nightly 时可以在命令行用 --set 覆盖：
    #   --set sglang.args.TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121"
    # TORCH         = ""

    CMAKE_BUILD_PARALLEL_LEVEL = "8"

    PIP_DISABLE_PIP_VERSION_CHECK = "1"
    PYTHONUNBUFFERED              = "1"
    HF_HOME                       = "/workspace/hf"
    HF_HUB_ENABLE_HF_TRANSFER     = "1"

    # 默认给 SGLang 的模型和服务配置（跑 Qwen2.5-7B-Instruct）
    SGLANG_MODEL  = "Qwen/Qwen2.5-3B-Instruct"
    SGLANG_HOST   = "0.0.0.0"
    SGLANG_PORT   = "30000"
    SGLANG_EXTRA  = "--attention-backend torch-sdp --sampling-backend torch"

    # ccache 相关配置，给 CUDA / C++ 编译加速用的
    CCACHE_DIR      = "/root/.ccache"
    CCACHE_COMPRESS = "1"
    CCACHE_MAXSIZE  = "10G"
  }
}
