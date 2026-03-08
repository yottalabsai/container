# Changelog

All notable changes to this repository are documented here.

## [Unreleased]

### Added
- Apache 2.0 license (replaced MIT)
- `CODE_OF_CONDUCT.md`
- `CHANGELOG.md`

## [2025-03-07]

### Added
- `github-runner` official template — GPU-enabled GitHub Actions self-hosted runner
- `openclaw` template updates: new docker-bake.hcl, refactored post_start startup flow
- `paddle` template

### Changed
- Translated all Chinese comments and text across `official-templates/` to English
- Updated `wan22-comfyui` and `openclaw` Dockerfiles with improved startup logic

### Removed
- Archived legacy templates: `gpt4all`, `log-debugger`, `sd-auto-base`, `sd-models`, `sd-torture-test`, `sd-vlad-base`, `torch-cuda12`

## [2025-02-01]

### Added
- `dflash` template — high-performance LLM inference with speculative decoding
- `verl-vllm` template — VERL with vLLM for efficient rollout generation
- `vllm-qwen` template — vLLM inference server pre-loaded with Qwen3
- `wan21-comfyui` template — Wan 2.1 video generation via ComfyUI
- `wan22-comfyui` template — Wan 2.2 video generation via ComfyUI
- `skyrl` template — SkyRL distributed reinforcement learning framework
- `ai-toolkit` template — AI/ML fine-tuning toolkit
- `openclaw` template — vLLM + OpenClaw Gateway
- `banana` template — API gateway for LLM inference
- Docker Buildx Bake support across all templates
- `CONTRIBUTING.md`, `SECURITY.md`, GitHub issue and PR templates

### Changed
- Fixed missing `group "default"` in bake files across templates
- Improved README with build instructions and template reference table

## [2024-01-01]

### Added
- Initial templates: `base`, `pytorch`, `tensorflow`, `comfyui`, `comfyui-nunchaku`, `flux1dev-comfyui`, `unsloth`, `verl`, `miles`, `sglang`, `vs-code`, `vscode-server`
- Shared `start.sh` infrastructure for platform integration (SSH, Nginx, JupyterLab)
