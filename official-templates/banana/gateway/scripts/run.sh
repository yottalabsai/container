#!/usr/bin/env bash
set -euo pipefail

: "${UPSTREAM_BASE_URL:=https://api.openai.com}"
: "${UPSTREAM_API_KEY:=}"
: "${UPSTREAM_DEFAULT_MODEL:=}"

exec /gateway
