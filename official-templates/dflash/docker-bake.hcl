variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026010901" }

group "default" {
  targets = ["pytorch290"]
}

group "dflash" {
  targets   = ["dflash"]
  platforms = ["linux/amd64"]
}

group "cuda" {
  targets   = ["pytorch290"]
  platforms = ["linux/amd64"]
}

target "pytorch290" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/pytorch:2.9.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE     = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11.14"
    TORCH          = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
  }
}

target "dflash" {
  inherits   = ["pytorch290"]
  platforms  = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/dflash:pytorch:2.9.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"
  ]

  args = {
    BASE_IMAGE      = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION  = "3.11.14"
    TORCH           = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
    INSTALL_DFLASH  = "1"
    DFLASH_REPO     = "https://github.com/z-lab/dflash.git"
    DFLASH_REF      = "main"
  }
}
