# Banana template + Go Model Gateway

This folder adds a **Go-based Model API gateway service** into your existing container-template runtime.

Key idea: your **public `/start.sh`** already executes `/post_start.sh` near the end of the boot sequence, so we simply drop a `post_start.sh` here to start the Go gateway in the background.

- `/start.sh` flow: start nginx -> run `/pre_start.sh` -> setup ssh/jupyter -> export env -> run `/post_start.sh` -> `sleep infinity`.

## What's included

- `gateway/`: standalone Go module implementing a simple Model API proxy
  - supports `/v1/chat/completions` with `stream=true` (SSE pass-through)
  - supports `/v1/embeddings`
  - `GET /healthz`
- `Dockerfile`: keeps all your existing CUDA/Python/Jupyter setup, plus a Go build stage
- `post_start.sh`: starts `/opt/gateway/gateway` and writes logs to `/workspace/logs`
- `docker-bake.hcl`: buildx bake target named `banana`

## Build

From this folder:

```bash
docker buildx bake

docker buildx bake banana --no-cache --push
```

Or classic build:

```bash
docker build -t banana-gateway:local .
```

## Run (local)

```bash
docker run --rm -p 8080:8080 \
  -e UPSTREAM_BASE_URL=https://api.openai.com \
  -e UPSTREAM_API_KEY=YOUR_KEY \
  -e UPSTREAM_DEFAULT_MODEL=gpt-4o-mini \
  banana-gateway:local
```

## Configure

Environment variables (gateway):

- `ADDR` (default `:8080`)
- `UPSTREAM_BASE_URL` (e.g. `https://api.openai.com`)
- `UPSTREAM_API_KEY` (injected as `Authorization: Bearer <key>`)
- `UPSTREAM_DEFAULT_MODEL` (optional, used when request body has no `model`)
- `RESPECT_CLIENT_AUTH` (optional, if `true` and client already sends `Authorization`, gateway won't override)
- `RATE_LIMIT_RPS` / `RATE_LIMIT_BURST` (optional, 0 disables)

Logs:

- `/workspace/logs/gateway.out.log`
- `/workspace/logs/gateway.err.log`

```bash
curl http://127.0.0.1:8080/healthz

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [
      {"role":"user","content":"hello"}
    ]
  }'

curl -N http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o-mini",
    "stream": true,
    "messages": [
      {"role":"user","content":"write a haiku about gateways"}
    ]
  }'
```