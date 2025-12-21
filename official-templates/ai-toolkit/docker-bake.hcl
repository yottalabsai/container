variable "PUBLISHER"   { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025122201" }

variable "BASE_IMAGE"  { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }
variable "PYTHON_VER"  { default = "3.11" }
variable "AITK_PORT"   { default = "8675" }

variable "TORCH_CHANNEL"           { default = "stable" }
variable "TORCH_VERSION"           { default = "2.7.0" }
variable "TORCH_VISION_VERSION"    { default = "0.22.0" }
variable "TORCH_CUDA"              { default = "cu126" }
variable "TORCH_NIGHTLY_INDEX_URL" { default = "https://download.pytorch.org/whl/nightly" }

group "default" { targets = ["ai-toolkit"] }

target "ai-toolkit" {
  description = "AI Toolkit UI + 训练镜像"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/ai-toolkit:cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE              = BASE_IMAGE
    PYTHON_VERSION          = PYTHON_VER
    AITK_PORT               = AITK_PORT
    TORCH_CHANNEL           = TORCH_CHANNEL
    TORCH_VERSION           = TORCH_VERSION
    TORCH_VISION_VERSION    = TORCH_VISION_VERSION
    TORCH_CUDA              = TORCH_CUDA
    TORCH_NIGHTLY_INDEX_URL = TORCH_NIGHTLY_INDEX_URL
  }
}
