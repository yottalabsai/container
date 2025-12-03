# ==============================
# Build Variables
# ==============================
variable "PUBLISHER" {
  default = "yottalabsai"
}

variable "TAG_SUFFIX" {
  default = "2025102101"
}

# ==============================
# Build Groups
# ==============================
# 默认只构建 vllm-qwen
group "cuda" {
  targets   = ["vllm-qwen"]
  platforms = ["linux/amd64"]
}

# ==============================
# vLLM + Qwen3-30B-A3B 镜像构建
# ==============================
target "vllm-qwen" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  # 镜像 tag（双标签同你原格式）
  tags = [
    "${PUBLISHER}/qwen:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  # build context（与你 flux 定义保持一致）
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  # ==============================
  # Build Args → 对应 Dockerfile 中 ARG
  # ==============================
  args = {
    BASE_IMAGE     = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11"
    UBUNTU_USER    = "ubuntu"

    # ------------------------------
    # 运行模型：默认使用 Qwen3-30B-A3B-Instruct
    # ------------------------------
    VLLM_MODEL = "Qwen/Qwen3-30B-A3B-Instruct-2507"
    VLLM_HOST  = "0.0.0.0"
    VLLM_PORT  = "8000"

    # ------------------------------
    # vLLM 性能参数
    # ------------------------------
    TP_SIZE       = "1"
    MAX_MODEL_LEN = "32768"
    GPU_MEM_UTIL  = "0.92"

    # ------------------------------
    # 大模型下载模块
    # ------------------------------
    ENABLE_MODEL_DOWNLOAD = "true"
    HF_MODEL_ID           = "Qwen/Qwen3-30B-A3B-Instruct-2507"
    HF_TOKEN              = ""   # 可在 CI 中覆盖

    # ------------------------------
    # Flash 加速组件
    # ------------------------------
    INSTALL_FLASHATTN  = "false"
    INSTALL_FLASHINFER = "false"
  }
}
