# ==============================
# Build Variables
# ==============================
variable "PUBLISHER" {
  default = "yottalabs"
  description = "Docker registry publisher/organization name (official: yottalabs)"
}

variable "TAG_SUFFIX" {
  default = "2025102101"
  description = "Version timestamp for image tagging"
}

variable "PYTHON_VERSION" {
  default = "3.11"
  description = "Python runtime version"
}

variable "BASE_IMAGE" {
  default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
  description = "NVIDIA CUDA base image with Ubuntu 22.04"
}

variable "UBUNTU_USER" {
  default = "user"
  description = "Default user name "
}

# ==============================
# Model Configuration
# ==============================
variable "VLLM_MODEL" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
  description = "Model identifier for vLLM runtime"
}

variable "HF_MODEL_ID" {
  default = "Qwen/Qwen3-30B-A3B-Instruct-2507"
  description = "HuggingFace model ID for downloading"
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
  description = "Tensor parallel size (number of GPUs for model parallelism)"
}

variable "MAX_MODEL_LEN" {
  default = "32768"
  description = "Maximum model context length (tokens)"
}

variable "GPU_MEM_UTIL" {
  default = "0.75"
  description = "GPU memory utilization ratio (0.75 = 75%)"
}

# ==============================
# Optional Build Features
# ==============================
variable "INSTALL_FLASHATTN" {
  default = "false"
  description = "Install flash-attention for faster inference (increases build time ~10min)"
}

variable "INSTALL_FLASHINFER" {
  default = "false"
  description = "Install flashinfer for optimized inference (increases build time ~5min)"
}

# ==============================
# Authentication
# ==============================
variable "HF_TOKEN" {
  default     = ""
  description = "HuggingFace access token (REQUIRED for model download)"   
}

# ==============================
# Build Groups
# ==============================
group "default" {
  targets = ["openclaw"]
}

# ==============================
# Target: OpenClaw with vLLM + Qwen
# ==============================
target "openclaw" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  # Official tags for Docker Hub
  tags = [
    "${PUBLISHER}/openclaw:latest",
  ]

  # External build contexts (if using multi-directory setup)
  # Comment out if files are in same directory as Dockerfile
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
}

