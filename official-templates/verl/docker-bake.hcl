# ==============================
# Verl Official Template (Yotta)
# ==============================

variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026013001" }

group "default" {
  targets = ["verl"]
}

target "verl" {
  description = "Verl (LLM post-training / RL) environment with a Qwen2.5-0.5B-Instruct demo"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/verl:py3.11-cuda12.8.1-ubuntu22.04",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
}
