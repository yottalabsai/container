# Go Model Gateway (OpenAI-compatible passthrough)

A lightweight **Model API gateway/proxy service**:
- Exposes OpenAI-style endpoints: `/v1/chat/completions`, `/v1/embeddings`, `/v1/responses`
- Forwards requests internally to your **UPSTREAM Model API** (default `https://api.openai.com`)
- Supports **SSE passthrough for streaming** (pure byte-stream forwarding, no content parsing)
- Supports optional default model injection, basic rate limiting, and structured logging

## Quick Start (local)

```bash
export UPSTREAM_BASE_URL=https://api.openai.com
export UPSTREAM_API_KEY=YOUR_KEY
export UPSTREAM_DEFAULT_MODEL=gpt-4o-mini

go run ./cmd/gateway
# listen :8080
```

Health:
```bash
curl -s http://127.0.0.1:8080/healthz
```

Chat (non-stream):
```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"hi"}]}'
```

Chat (stream):
```bash
curl -N http://127.0.0.1:8080/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"gpt-4o-mini","stream":true,"messages":[{"role":"user","content":"tell me a haiku"}]}'
```

## Config (env)

| Env | Default | Note |
|---|---:|---|
| `ADDR` | `:8080` | Service listen address |
| `UPSTREAM_BASE_URL` | `https://api.openai.com` | Upstream API base URL |
| `UPSTREAM_API_KEY` | *(empty)* | Upstream key (not injected if empty) |
| `UPSTREAM_DEFAULT_MODEL` | *(empty)* | Default model injected if request body has no `model` field |
| `UPSTREAM_API_KEY_HEADER` | `Authorization` | Auth header, default `Authorization: Bearer <key>` |
| `RESPECT_CLIENT_AUTH` | `false` | If client already sends Authorization, do not override |
| `LOG_REQUESTS` | `true` | Extra request logging (chi middleware) |
| `LOG_LEVEL` | `info` | debug/info/warn/error |
| `RATE_LIMIT_RPS` | `0` | Simple rate limit, 0=disabled |
| `RATE_LIMIT_BURST` | `0` | Burst size, defaults to ≈RPS |

## Build image

```bash
docker build -t go-model-gateway:local .
```

Or buildx bake:

```bash
docker buildx bake
```
