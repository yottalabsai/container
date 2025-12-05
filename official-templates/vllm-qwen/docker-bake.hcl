# ==============================
# Build Variables
# ==============================
variable "PUBLISHER" {
  default = "yottalabsai"
}

variable "TAG_SUFFIX" {
  default = "2025102101"
}

variable "HF_TOKEN" {
  # 用于从 HuggingFace 下载私有 / gated 模型的访问令牌。
  # - 默认留空（不在镜像里 bake token）
  # - CI / 本地构建时可以通过环境变量 HF_TOKEN 覆盖：
  #     HF_TOKEN=xxx docker buildx bake cuda
  default = ""
}

variable "MAX_MODEL_LEN" {
  # vLLM 的最大上下文长度（token 数）。
  # - 数值越大，占用显存越多（Qwen3-30B + 32K context 对单卡 32G 压力很大）
  # - 对单卡 32G 建议从 4096 / 8192 起试，确认稳定后再慢慢调大
  default = "32768"
}

variable "GPU_MEM_UTIL" {
  # vLLM 可用 GPU 显存利用率上限（0~1）。
  # - 比如 0.9 表示最多用 90% 显存，给系统 / 其他进程留一点空间
  # - 过高（比如 0.95+）在大模型场景下更容易触发 OOM
  default = "0.92"
}

variable "TP_SIZE" {
  # Tensor Parallel（张量并行）切分数。
  # - 1 表示单卡加载整个模型
  # - >1 时需要多卡，并行切分权重（比如 2 / 4）
  # - 对于 30B 模型 + 大上下文长度，建议在多卡环境下提升 TP_SIZE
  default = "1"
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
    TP_SIZE       = "${TP_SIZE}"
    MAX_MODEL_LEN = "${MAX_MODEL_LEN}"
    GPU_MEM_UTIL  = "${GPU_MEM_UTIL}"

    # ------------------------------
    # 大模型下载模块
    # ------------------------------
    ENABLE_MODEL_DOWNLOAD = "true"
    HF_MODEL_ID           = "Qwen/Qwen3-30B-A3B-Instruct-2507"
    HF_TOKEN              = "${HF_TOKEN}"   # 可在 CI 中覆盖

    # ------------------------------
    # Flash 加速组件
    # ------------------------------
    INSTALL_FLASHATTN  = "false"
    INSTALL_FLASHINFER = "false"
  }
}
