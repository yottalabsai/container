variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2026010901" }

group "default" {
  targets = ["dflash"]
}


target "dflash" {
  platforms  = ["linux/amd64"]
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/dflash:py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE      = "nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
    PYTHON_VERSION  = "3.11.14"
    TORCH_INDEX_URL = "https://download.pytorch.org/whl/cu128"
    TORCH           = "torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1"
    INSTALL_DFLASH  = "1"
    DFLASH_REPO     = "https://github.com/z-lab/dflash.git"
    DFLASH_REF      = "main"
  }
}
