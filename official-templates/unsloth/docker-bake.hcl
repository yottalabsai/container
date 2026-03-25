# ==============================
# Unsloth Official + Yotta Wrapper build
# ==============================

variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025122201" }

# Official recommendation: use unsloth/unsloth directly as the base
variable "BASE_IMAGE" { default = "unsloth/unsloth:latest" }

# Group: default builds only the single unsloth target
group "default" {
  targets = ["unsloth"]
}

# ==============================
# Unsloth - official base + Yotta tools
# ==============================
target "unsloth" {
  description = "Official Unsloth Docker image with Yotta tooling"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/unsloth:0.6.9-py3.11-cuda12.1-cudnn-devel-ubuntu22.04",
  ]

  # Keeping contexts here to align with your existing setup
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE = "${BASE_IMAGE}"
  }
}
