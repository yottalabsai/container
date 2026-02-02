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

variable "UBUNTU_USER" {
  default = "ubuntu"
}

# ==============================
# Model Configuration
# ==============================
variable "VLLM_MODEL" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
}

variable "HF_MODEL_ID" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
}

# ==============================
# vLLM Runtime Defaults
# ==============================
variable "VLLM_PORT" {
  default = "8001"
  description = "Default vLLM API port (avoids common 8000 conflicts)"
}

variable "TP_SIZE" {
  default = "4"
  description = "Tensor parallel size"
}

variable "MAX_MODEL_LEN" {
  default = "32768"
  description = "Maximum model context length"
}

variable "GPU_MEM_UTIL" {
  default = "0.92"
  description = "GPU memory utilization ratio"
}

# ==============================
# Optional Build Features
# ==============================
variable "INSTALL_FLASHATTN" {
  default = "false"
  description = "Install flash-attention for faster inference"
}

variable "INSTALL_FLASHINFER" {
  default = "false"
  description = "Install flashinfer for optimized inference"
}

# ==============================
# Authentication
# ==============================
variable "HF_TOKEN" {
  default     = ""
  description = "HuggingFace access token (REQUIRED for private models)"
}

# ==============================
# Build Groups
# ==============================
group "default" {
  targets = ["vllm-qwen"]
}

group "cuda" {
  targets = ["vllm-qwen"]
}

group "all" {
  targets = ["vllm-qwen", "vllm-qwen-flashattn"]
}

# ==============================
# Target: vLLM + Qwen + Moltbot (Base)
# ==============================
target "vllm-qwen" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"
  
  tags = [
    "${PUBLISHER}/qwen:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/qwen:vllm-cuda12.8.1-ubuntu22.04-latest",
    "${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-cuda12.8.1-ubuntu22.04-latest",
    "${PUBLISHER}/qwen:latest",
  ]
  
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
  
  args = {
    BASE_IMAGE         = BASE_IMAGE
    PYTHON_VERSION     = PYTHON_VERSION
    UBUNTU_USER        = UBUNTU_USER
    HF_MODEL_ID        = HF_MODEL_ID
    INSTALL_FLASHATTN  = INSTALL_FLASHATTN
    INSTALL_FLASHINFER = INSTALL_FLASHINFER
    HF_TOKEN           = HF_TOKEN
  }
  
  labels = {
    "org.opencontainers.image.title"       = "vLLM Qwen with Moltbot"
    "org.opencontainers.image.description" = "vLLM inference server with Qwen model and Moltbot integration"
    "org.opencontainers.image.vendor"      = "Yotta Labs AI"
    "org.opencontainers.image.authors"     = "Yotta Labs AI"
    "org.opencontainers.image.version"     = TAG_SUFFIX
    "ai.yottalabs.model"                   = HF_MODEL_ID
    "ai.yottalabs.framework"               = "vLLM"
    "ai.yottalabs.cuda.version"            = "12.8.1"
    "ai.yottalabs.python.version"          = PYTHON_VERSION
  }
  
}

# ==============================
# Target: vLLM + Qwen + Moltbot (with FlashAttention)
# ==============================
target "vllm-qwen-flashattn" {
  inherits   = ["vllm-qwen"]
  
  tags = [
    "${PUBLISHER}/openclaw:vllm-flashattn-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}" ]
  
  args = {
    BASE_IMAGE         = BASE_IMAGE
    PYTHON_VERSION     = PYTHON_VERSION
    UBUNTU_USER        = UBUNTU_USER
    HF_MODEL_ID        = HF_MODEL_ID
    INSTALL_FLASHATTN  = "true"
    INSTALL_FLASHINFER = "false"
    HF_TOKEN           = HF_TOKEN
  }
  
  labels = {
    "org.opencontainers.image.title"       = "vLLM Qwen with Moltbot (FlashAttention)"
    "org.opencontainers.image.description" = "vLLM inference server with Qwen model, Moltbot, and FlashAttention optimization"
    "org.opencontainers.image.vendor"      = "Yotta Labs AI"
    "org.opencontainers.image.authors"     = "Yotta Labs AI"
    "org.opencontainers.image.version"     = TAG_SUFFIX
    "ai.yottalabs.model"                   = HF_MODEL_ID
    "ai.yottalabs.framework"               = "vLLM"
    "ai.yottalabs.optimization"            = "FlashAttention"
    "ai.yottalabs.cuda.version"            = "12.8.1"
    "ai.yottalabs.python.version"          = PYTHON_VERSION
  }
}

# ==============================
# Target: vLLM + Qwen + Moltbot (with FlashInfer)
# ==============================
target "vllm-qwen-flashinfer" {
  inherits   = ["vllm-qwen"]
  
  tags = [
    "${PUBLISHER}/qwen:vllm-flashinfer-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/qwen:vllm-flashinfer-cuda12.8.1-ubuntu22.04-latest",
    "${PUBLISHER}/vllm:qwen-flashinfer-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-flashinfer-cuda12.8.1-ubuntu22.04-latest",
  ]
  
  args = {
    BASE_IMAGE         = BASE_IMAGE
    PYTHON_VERSION     = PYTHON_VERSION
    UBUNTU_USER        = UBUNTU_USER
    HF_MODEL_ID        = HF_MODEL_ID
    INSTALL_FLASHATTN  = "false"
    INSTALL_FLASHINFER = "true"
    HF_TOKEN           = HF_TOKEN
  }
  
  labels = {
    "org.opencontainers.image.title"       = "vLLM Qwen with Moltbot (FlashInfer)"
    "org.opencontainers.image.description" = "vLLM inference server with Qwen model, Moltbot, and FlashInfer optimization"
    "org.opencontainers.image.vendor"      = "Yotta Labs AI"
    "org.opencontainers.image.authors"     = "Yotta Labs AI"
    "org.opencontainers.image.version"     = TAG_SUFFIX
    "ai.yottalabs.model"                   = HF_MODEL_ID
    "ai.yottalabs.framework"               = "vLLM"
    "ai.yottalabs.optimization"            = "FlashInfer"
    "ai.yottalabs.cuda.version"            = "12.8.1"
    "ai.yottalabs.python.version"          = PYTHON_VERSION
  }
}

# ==============================
# Target: vLLM + Qwen + Moltbot (Full Optimization)
# ==============================
target "vllm-qwen-full" {
  inherits   = ["vllm-qwen"]
  
  tags = [
    "${PUBLISHER}/qwen:vllm-full-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/qwen:vllm-full-cuda12.8.1-ubuntu22.04-latest",
    "${PUBLISHER}/vllm:qwen-full-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
    "${PUBLISHER}/vllm:qwen-full-cuda12.8.1-ubuntu22.04-latest",
  ]
  
  args = {
    BASE_IMAGE         = BASE_IMAGE
    PYTHON_VERSION     = PYTHON_VERSION
    UBUNTU_USER        = UBUNTU_USER
    HF_MODEL_ID        = HF_MODEL_ID
    INSTALL_FLASHATTN  = "true"
    INSTALL_FLASHINFER = "true"
    HF_TOKEN           = HF_TOKEN
  }
  
  labels = {
    "org.opencontainers.image.title"       = "vLLM Qwen with Moltbot (Full Optimization)"
    "org.opencontainers.image.description" = "vLLM inference server with Qwen model, Moltbot, FlashAttention, and FlashInfer"
    "org.opencontainers.image.vendor"      = "Yotta Labs AI"
    "org.opencontainers.image.authors"     = "Yotta Labs AI"
    "org.opencontainers.image.version"     = TAG_SUFFIX
    "ai.yottalabs.model"                   = HF_MODEL_ID
    "ai.yottalabs.framework"               = "vLLM"
    "ai.yottalabs.optimization"            = "FlashAttention+FlashInfer"
    "ai.yottalabs.cuda.version"            = "12.8.1"
    "ai.yottalabs.python.version"          = PYTHON_VERSION
  }
}

