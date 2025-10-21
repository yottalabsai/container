variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025102101" }

group "default" { targets = ["verl-vllm"] }

target "verl-vllm" {
  description = "Verl-Wan2.2 模型的 vLLM OpenAI API 服务"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64","linux/arm64"]

  tags = [
    "${PUBLISHER}/verl:vllm-cuda12.8.1-ubuntu22.04-${TAG_SUFFIX}"
  ]

  args = {
    PYTHON_VERSION    = "3.11"
    VLLM_PORT         = "8000"
    INSTALL_FLASHATTN = "false"

    # 默认加载 Verl-Wan2.2
    MODEL_NAME        = "Verl/Wan2.2"
    TP_SIZE           = "1"
    MAX_MODEL_LEN     = "32768"
    GPU_MEM_UTIL      = "0.92"
  }
}