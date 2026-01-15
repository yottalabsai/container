# Go Model Gateway (OpenAI-compatible passthrough)

一个轻量的 **Model API 网关/代理服务**：
- 对外暴露 OpenAI 风格接口：`/v1/chat/completions`, `/v1/embeddings`, `/v1/responses`
- 对内把请求转发到你的 **UPSTREAM Model API**（默认 `https://api.openai.com`）
- 支持 **stream=true 的 SSE 透传**（不解析内容，纯字节流转发）
- 支持可选默认模型注入、基础限流、结构化日志

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
| `ADDR` | `:8080` | 服务监听地址 |
| `UPSTREAM_BASE_URL` | `https://api.openai.com` | 上游 API Base URL |
| `UPSTREAM_API_KEY` | *(empty)* | 上游 Key（为空则不注入） |
| `UPSTREAM_DEFAULT_MODEL` | *(empty)* | 若请求体无 `model`，则注入默认模型 |
| `UPSTREAM_API_KEY_HEADER` | `Authorization` | 认证头，默认 `Authorization: Bearer <key>` |
| `RESPECT_CLIENT_AUTH` | `false` | 若客户端已带 Authorization，则不覆盖 |
| `LOG_REQUESTS` | `true` | 额外请求日志（chi middleware） |
| `LOG_LEVEL` | `info` | debug/info/warn/error |
| `RATE_LIMIT_RPS` | `0` | 简单限流，0=关闭 |
| `RATE_LIMIT_BURST` | `0` | burst，默认≈RPS |

## Build image

```bash
docker build -t go-model-gateway:local .
```

Or buildx bake:

```bash
docker buildx bake
```
