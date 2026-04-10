variable "PUBLISHER"    { default = "yottalabsai" }
variable "TAG_SUFFIX"   { default = "2026041001" }
variable "VLLM_VERSION" { default = "0.9.0" }
variable "HERMES_MODEL" { default = "NousResearch/Hermes-3-Llama-3.1-8B" }
variable "BASE_IMAGE"   { default = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04" }

group "default" {
  targets = ["hermes"]
}

target "hermes" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/hermes:${TAG_SUFFIX}",
    "${PUBLISHER}/hermes:latest",
  ]

  args = {
    BASE_IMAGE    = BASE_IMAGE
    VLLM_VERSION  = VLLM_VERSION
    HERMES_MODEL  = HERMES_MODEL
  }
}
