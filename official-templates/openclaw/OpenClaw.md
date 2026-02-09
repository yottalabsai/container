# OpenClaw Image Documentation (Generated from Dockerfile)

This document describes the current **OpenClaw Docker image**, its build-time parameters, runtime behavior, and embedded components, with a particular focus on the large language model **Qwen3-30B-A3B-Instruct-2507**.

---

## 1. Image Purpose

This image serves as a general-purpose GPU/CPU runtime base for OpenClaw workloads.  
It is designed to host long-running services, tool/workflow execution, and optional operational entry points such as Jupyter or SSH.

---

## 2. Build Arguments

The following parameters are injected via `docker buildx bake` or `docker build` and directly affect how the image is built.

### 2.1 Base Image

- `BASE_IMAGE`  
  The CUDA / system base image used for this build.  
  The exact value is defined in the Dockerfile.

---

### 2.2 Python Version

- `PYTHON_VERSION`  
  Controls which Python version is installed during build.

⚠️ **Important note**  
If the Dockerfile installs Python via `apt` using `python${PYTHON_VERSION}`, the package manager typically only supports **major.minor** versions (e.g. `3.11`), not full patch versions such as `3.11.14`.

---

### 2.3 PyTorch / CUDA Stack

- `TORCH`  
  Specifies the PyTorch / torchvision / torchaudio installation command, usually bound to a specific CUDA version.

- `NCCL_TESTS_VERSION` (optional)  
  Version of NCCL tests compiled into the image.

---

## 3. HuggingFace Model Download (Build Time)

During image build, the Dockerfile executes `huggingface-cli download` to fetch the model directly into the image filesystem.

This step **requires a non-empty `HF_TOKEN`**.  
If the token is missing, the build will fail immediately with exit code `2`.

---

### 3.1 Model Configuration

- `HF_MODEL_ID`  
  ```
  Qwen/Qwen3-30B-A3B-Instruct-2507
  ```

- `HF_HOME`  
  ```
  /workspace/hf
  ```

- Model download path  
  ```
  /workspace/hf/Qwen/Qwen3-30B-A3B-Instruct-2507
  ```

---

### 3.2 Providing `HF_TOKEN`

`HF_TOKEN` must be supplied at build time.

#### Option A: Environment variable (recommended)

```bash
HF_TOKEN=hf_xxx docker buildx bake <target> --no-cache
```

#### Option B: Explicit bake override

```bash
docker buildx bake <target> \
  --set <target>.args.HF_TOKEN=hf_xxx \
  --no-cache
```

#### When using `sudo`

If you run `docker buildx bake` with `sudo`, environment variables may be stripped.

Use:

```bash
sudo -E HF_TOKEN=hf_xxx docker buildx bake <target> --no-cache
```

---

### 3.3 Security Notice

You may see warnings such as:

```
SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data
```

This is expected when passing secrets via build arguments.

For higher security guarantees, consider migrating to **BuildKit secrets**, which requires Dockerfile changes.

---

## 4. Runtime Entry Points and Ports

Runtime behavior is defined by the Dockerfile `ENTRYPOINT` / `CMD`.

- Do **not** override the startup script unless you fully understand the initialization logic.
- Port exposure depends on the services enabled inside the image.

Commonly used ports include:

- `22` – SSH
- `8888` – Jupyter
- Service-specific ports (e.g. `8080`)

---

## 5. Recommended Runtime Usage

### 5.1 Local GPU Run

```bash
docker run --gpus all --rm -it \
  -p 22:22 \
  -p 8888:8888 \
  -v $(pwd)/data:/workspace/data \
  <image>:<tag>
```

---

### 5.2 Mounting HF Cache (Recommended for Iteration)

To avoid embedding large model files into the image layer and to enable cache reuse:

```bash
docker run --gpus all --rm -it \
  -e HF_HOME=/workspace/hf \
  -v /data/hf-cache:/workspace/hf \
  <image>:<tag>
```

> Note:  
> The current Dockerfile downloads the model **at build time**.  
> Switching to runtime download or shared cache requires Dockerfile changes.

---

## 6. Common Failure Modes

### 6.1 `python: command not found`

**Cause**

- `PYTHON_VERSION` was set to a full patch version (e.g. `3.11.14`)
- Dockerfile installs Python via `apt`, which does not provide such packages

**Resolution**

- Pass `PYTHON_VERSION=3.11` via `docker-bake.hcl`
- Or modify the Dockerfile to normalize major/minor automatically

---

### 6.2 `HF_TOKEN is empty` (exit code 2)

**Cause**

- `HF_TOKEN` was not passed through `docker-bake.hcl`
- Environment variable lost due to `sudo`

**Resolution**

- Declare `HF_TOKEN` in bake `args`
- Inject it via environment variable or `--set`

---

## 7. Relationship to Previous Generic Documentation

The original `OpenClaw.md` document is intentionally **generic**, describing what the container is in abstract terms.

This document complements it by documenting:

- Actual Dockerfile behavior
- Build-time HuggingFace model download
- Fixed model: `Qwen3-30B-A3B-Instruct-2507`
- Real-world failure modes and debugging paths

---

## 8. Change Policy

This document is derived directly from the current Dockerfile.  
If the Dockerfile changes, this document **must be reviewed and updated accordingly**.
