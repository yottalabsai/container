variable "PUBLISHER" {
  default = "yottalabsai"
}

variable "TAG_SUFFIX" {
  default = "2025102101"
}

group "cuda" {
  targets   = ["vllm-qwen"]
  platforms = ["linux/amd64"]
}

target "vllm-qwen" {
  platform   = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/qwen:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  # 先保留你原来的上下文结构，方便之后复用模版
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11"
    UBUNTU_USER    = "ubuntu"

    # 默认：Qwen2.5-3B-Instruct
    VLLM_MODEL = "Qwen/Qwen2.5-3B-Instruct"
    VLLM_HOST  = "0.0.0.0"
    VLLM_PORT  = "8000"

    # 资源相关
    TP_SIZE       = "1"
    MAX_MODEL_LEN = "32768"
    GPU_MEM_UTIL  = "0.92"

    # 加速组件开关
    INSTALL_FLASHATTN  = "false"
    INSTALL_FLASHINFER = "false"
  }
}
