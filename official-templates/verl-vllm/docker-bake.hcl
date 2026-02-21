variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025102101" }

group "default" {
  targets = ["verl-vllm"]
}

target "verl-vllm" {
  description = "Base Verl + vLLM image (no model, no business start.sh)"

  # Main build context: current directory (official-templates/verl-vllm)
  context    = "."
  dockerfile = "Dockerfile"

  # Extra contexts: used for scripts / proxy / logo
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
    BASE_IMAGE     = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION    = "3.11"
  }
}
