

# ==============================
# SkyRL Official + Yotta Wrapper 构建
# ==============================

variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "20260115" }
variable "BASE_IMAGE" { default = "novaskyai/skyrl-train-ray-2.51.1-py3.12-cu12.8-megatron" }
variable "JUPYTER_PASSWORD" { default = "ubuntu" }

group "default" {
  targets = ["skyrl"]
}

target "skyrl" {
  description = "Official SkyRL Docker image with Ray and Yotta tooling"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
  "${PUBLISHER}/skyrl:ray2.51-py3.11-cuda12.1-cudnn-devel-ubuntu22.04",
]
  # 为了和现有体系对齐，保留 contexts
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE = "${BASE_IMAGE}"
    JUPYTER_PASSWORD = "${JUPYTER_PASSWORD}"
  }
}
