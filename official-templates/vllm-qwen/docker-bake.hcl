# ==============================
# Build Variables
# ==============================
variable "PUBLISHER" {
  default = "yottalabsai"
}

variable "TAG_SUFFIX" {
  default = "2025102101"
}

variable "PYTHON_VERSION" {
  default = "3.11"
}

variable "BASE_IMAGE" {
  default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
}

# vLLM defaults baked into image (can be overridden at runtime via env)
variable "VLLM_MODEL" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
}

variable "HF_MODEL_ID" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
}

variable "VLLM_PORT" {
  # 默认 8001：规避平台常见 8000 冲突
  default = "8001"
}

variable "TP_SIZE" {
  default = "1"
}

variable "MAX_MODEL_LEN" {
  default = "32768"
}

variable "GPU_MEM_UTIL" {
  default = "0.92"
}

# Optional build-time installs
variable "INSTALL_FLASHATTN" {
  default = "false"
}

variable "INSTALL_FLASHINFER" {
  default = "false"
}

# ==============================
# Build Groups
# ==============================
group "cuda" {
  targets   = ["vllm-qwen"]
  platforms = ["linux/amd64"]
}

# ==============================
# Target: vLLM + Qwen
# ==============================
target "vllm-qwen" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/qwen:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = "${BASE_IMAGE}"
    PYTHON_VERSION = "${PYTHON_VERSION}"
    UBUNTU_USER    = "ubuntu"

    # optional build-time accel
    INSTALL_FLASHATTN  = "${INSTALL_FLASHATTN}"
    INSTALL_FLASHINFER = "${INSTALL_FLASHINFER}"

    # NOTE:
    # vLLM/HF 默认值现在主要在 Dockerfile 的 ENV 里。
    # 如果你一定要通过 bake 注入默认值，也可以在 Dockerfile 改为 ARG->ENV 的映射。
  }
}
