# Contributing to Yotta Labs Container Images

Thank you for your interest in contributing. This guide covers how to add a new template or modify an existing one.

## Prerequisites

- Docker with [Buildx](https://docs.docker.com/build/buildx/) enabled
- Access to an NVIDIA GPU (for testing)
- NVIDIA Container Toolkit installed

## Adding a New Template

1. **Create a directory** under `official-templates/<your-template-name>/`.

2. **Add required files:**

   | File | Required | Description |
   |------|----------|-------------|
   | `Dockerfile` | Yes | Image build definition |
   | `docker-bake.hcl` | Yes | Buildx bake target configuration |
   | `README.md` | Yes | User-facing documentation |
   | `yotta.yaml` | Yes | Service port configuration |
   | `post_start.sh` | No | Runs after container start |

3. **Base your image** on an appropriate NVIDIA CUDA base (e.g., `nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04`).

4. **Include the platform dependencies** — your image must have `nginx`, `openssh-server`, and `jupyterlab` installed, and must copy `start.sh` from the shared `container-template/` context.

5. **Write a clear `README.md`** for the template. It will be displayed on Docker Hub and in the Yotta platform UI. It should include:
   - What is included (versions, frameworks)
   - Exposed ports table
   - Environment variables table (if any)
   - Quick start / verification steps
   - Build instructions

## Modifying an Existing Template

- Make your changes in the relevant template directory.
- Test your build locally before opening a pull request:

  ```bash
  docker buildx bake <target-name> --no-cache
  ```

- Verify the container starts and all services are reachable.

## Pull Request Guidelines

- Keep each PR focused on a single template or fix.
- Include a description of what changed and why.
- Update the template's `README.md` if the interface or versions changed.
- Do not commit secrets, API tokens, or internal hostnames.

## Shared Infrastructure

The `container-template/` directory contains shared files used by all templates:

| File | Purpose |
|------|---------|
| `start.sh` | Universal container entrypoint (starts SSH, Nginx, JupyterLab) |
| `proxy/nginx.conf` | Nginx configuration |
| `proxy/readme.html` | Default HTML page served before a service is ready |
| `yotta.txt` | Yotta Labs ASCII art displayed on login |

Changes to `container-template/` affect all templates — test broadly before merging.

## Reporting Issues

Use [GitHub Issues](../../issues) to report bugs or request new templates.
