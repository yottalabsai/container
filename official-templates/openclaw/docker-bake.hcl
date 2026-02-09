// OpenClaw / SGLang image build with docker buildx bake

variable "REGISTRY" { default = "" }
variable "IMAGE"    { default = "openclaw" }
variable "TAG"      { default = "latest" }

// these must match your build contexts used by: COPY --from=scripts/proxy/logo
variable "CTX_SCRIPTS" { default = "./scripts" }
variable "CTX_PROXY"   { default = "./proxy" }
variable "CTX_LOGO"    { default = "./logo" }

// if you need to override at build time:
//   docker buildx bake -f docker-bake.hcl \
//     --set openclaw.args.SGLANG_VERSION=0.5.8.post1 \
//     --set openclaw.tags=myrepo/openclaw:dev

group "default" {
  targets = ["openclaw"]
}

target "openclaw" {
  context    = "."
  dockerfile = "Dockerfile"

  // named contexts for multi-stage COPY --from=...
  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  // build args (match your Dockerfile ARG names)
  args = {
    PYTHON_VERSION     = "3.11.14"
    TORCH_INDEX_URL    = "https://download.pytorch.org/whl/cu128"
    TORCH              = "torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1"
    SGLANG_VERSION     = "0.5.8.post1"
    NCCL_TESTS_VERSION = "v2.13.11"
  }

  // output tag
  tags = ["${REGISTRY}${IMAGE}:${TAG}"]
}
