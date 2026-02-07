variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026010901" }

group "default" {
  targets = ["pytorch290"]
}

group "cuda" {
  targets   = ["pytorch290"]
  platforms = ["linux/amd64"]
}

target "pytorch290" {
  platforms  = ["linux/amd64"]
  dockerfile = "runtime.Dockerfile"

  tags = [
    "${PUBLISHER}/pytorch:2.9.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"
  ]

  contexts = {
    base    = "target:ml-runtime"
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = "base"
  }
}
