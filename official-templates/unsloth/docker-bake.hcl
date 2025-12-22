# ==============================
# Unsloth Official + Yotta Wrapper 构建
# ==============================

variable "PUBLISHER"  { default = "yottalabsai" }
variable "TAG_SUFFIX" { default = "2025122201" }

# 官方推荐：直接用 unsloth/unsloth 作为底座
variable "BASE_IMAGE" { default = "unsloth/unsloth:latest" }

# 组：default 只构建一个 unsloth 目标
group "default" {
  targets = ["unsloth"]
}

# ==============================
# Unsloth - 官方底座 + Yotta 工具
# ==============================
target "unsloth" {
  description = "Official Unsloth Docker image with Yotta tooling"
  dockerfile  = "Dockerfile"
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/unsloth-yotta:cu121-torch241-unsloth-${TAG_SUFFIX}",
  ]

  # 为了和你现有体系对齐，这里保留 contexts
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    BASE_IMAGE = "${BASE_IMAGE}"
  }
}
