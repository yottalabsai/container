variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default" {
  targets = ["verl-vllm"]
}

target "verl-vllm" {
  description = "基础 Verl + vLLM 镜像（不含模型、不含业务 start.sh）"

  # 主 build context：当前目录（official-templates/verl-vllm）
  context    = "."
  dockerfile = "Dockerfile"

  # 额外上下文：给 scripts / proxy / logo 用
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  platforms = ["linux/amd64", "linux/arm64"]

  tags = [
    "${PUBLISHER}/verl:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]

  args = {
    BASE_IMAGE     = "nvidia/cuda:12.6.2-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION    = "3.11"
  }
}
