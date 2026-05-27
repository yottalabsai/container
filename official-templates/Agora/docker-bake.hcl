# ==============================
# Agora (Pluralis-8B) Node — Yotta Official Template
# ==============================
variable "PUBLISHER"       { default = "yottalabsai" }
variable "TAG_SUFFIX"      { default = "20260527" }
variable "JUPYTER_PASSWORD" { default = "ubuntu" }

group "default" {
  targets = ["agora"]
}

target "agora" {
  description = "Yotta Agora node image — joins Pluralis-8B decentralized training"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]
  tags = [
    "${PUBLISHER}/agora:cu128-py3.11-ubuntu22.04-${TAG_SUFFIX}",
  ]
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }
  args = {
    JUPYTER_PASSWORD = "${JUPYTER_PASSWORD}"
  }
}
