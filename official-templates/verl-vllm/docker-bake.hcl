variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default" {
  targets = ["verl-vllm"]
}

target "verl-vllm" {
  description = "Verl-Wan2.2 模型的 vLLM OpenAI API 服务"

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
    PYTHON_VERSION    = "3.11"
    VLLM_PORT         = "8000"
    INSTALL_FLASHATTN = "false"

    # vLLM / Verl 相关参数
    VLLM_MODEL     = "Verl/Wan2.2"
    VLLM_EXTRA     = ""
    TP_SIZE        = "1"
    MAX_MODEL_LEN  = "32768"
    GPU_MEM_UTIL   = "0.92"
  }
}
