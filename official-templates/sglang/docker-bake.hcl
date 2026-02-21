variable "PUBLISHER" { default = "yottalabsai" }
variable "TAG_SUFFIX"  { default = "2025090901" }

# Build this sglang image by default
group "default" {
  targets = ["sglang"]
}

# An additional group can be added if needed, e.g. cuda-all
group "cuda" {
  targets = ["sglang"]
}

target "sglang" {
  description = "SGLang Runtime (CUDA 12.1.1 + PyTorch cu121)"
  dockerfile  = "Dockerfile"

  # Official CUDA images typically only support amd64; arm64 requires separate handling, so only amd64 is listed here
  platforms   = ["linux/amd64"]

  tags = [
    "${PUBLISHER}/pytorch:sglang-cuda12.1.1-ubuntu22.04-${TAG_SUFFIX}"
  ]

  contexts = {
    scripts = "../../container-template"
    proxy   = "../../container-template/proxy"
    logo    = "../../container-template"
  }

  args = {
    # Corresponds to the ARG declarations at the top of Dockerfile.bak
    BASE_IMAGE     = "nvidia/cuda:12.1.1-devel-ubuntu22.04"
    PYTHON_VERSION = "3.11"

    # Omitting TORCH = uses the “stable cu121” logic in Dockerfile.bak
    # To use nightly, override via the command line with --set:
    #   --set sglang.args.TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu121"
    # TORCH         = ""

    CMAKE_BUILD_PARALLEL_LEVEL = "8"

    PIP_DISABLE_PIP_VERSION_CHECK = "1"
    PYTHONUNBUFFERED              = "1"
    HF_HOME                       = "/workspace/hf"
    HF_HUB_ENABLE_HF_TRANSFER     = "1"

    # Default model and service config for SGLang (runs Qwen/Qwen2.5-3B-Instruct)
    SGLANG_MODEL  = "Qwen/Qwen2.5-3B-Instruct"
    SGLANG_HOST   = "0.0.0.0"
    SGLANG_PORT   = "30000"
    SGLANG_EXTRA  = "--trust-remote-code --mem-fraction-static 0.7 --disable-cuda-graph"

    # Enable auto TP in Dockerfile.bak (empty string or auto = automatically infer tp-size based on GPU count)
    SGLANG_TP = "auto"

    # Prefetch strategy: auto = single-GPU lazy, multi-GPU eager
    SGLANG_PREFETCH = "auto"

    # ccache configuration for accelerating CUDA / C++ compilation
    CCACHE_DIR      = "/root/.ccache"
    CCACHE_COMPRESS = "1"
    CCACHE_MAXSIZE  = "10G"
  }
}
