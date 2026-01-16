variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "latest" }
variable "BASE_IMAGE" { default = "radixark/miles:latest" }
variable "JUPYTER_PASSWORD" { default = "ubuntu" }
variable "PYTHON_VERSION" { default = "3.10" }


group "default" {
  targets = ["miles"]
}

target "miles" {
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]



  tags = [
    "${PUBLISHER}/miles:py3.11-cuda12.1-cudnn-devel-ubuntu22.04",
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE       = "${BASE_IMAGE}"
    JUPYTER_PASSWORD = "${JUPYTER_PASSWORD}"
    PYTHON_VERSION   = "${PYTHON_VERSION}"
  }
}

