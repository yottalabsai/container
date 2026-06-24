variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026032601" }

group "default" {
  targets = ["aws-neuron"]
}

target "aws-neuron" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/aws-neuron:py3.11-ubuntu22.04-${TAG_SUFFIX}"
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE                  = "ubuntu:22.04"
    TORCH_NEURONX_VERSION       = "2.8.*"
    NEURONX_CC_VERSION          = "2.21.*"
    MINI_SGLANG_NEURON_COMMIT   = "e984a5b7aaf539698b94e7f9fdadb1e40b8ff155"
  }
}
