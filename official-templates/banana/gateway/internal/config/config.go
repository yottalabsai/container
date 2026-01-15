package config

import (
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

type ServerConfig struct {
	Addr         string
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
}

type UpstreamConfig struct {
	BaseURL string
	APIKey  string
	// Optional. If empty, request body model is used.
	DefaultModel string
	// Header name to carry API key. Default: Authorization: Bearer <key>
	APIKeyHeader string
	// If true, do not overwrite Authorization header if already present.
	RespectClientAuth bool
}

type Config struct {
	Server      ServerConfig
	Upstream    UpstreamConfig
	LogRequests bool
	LogLevel    slog.Level

	// Simple rate limit (per-process). 0 disables.
	RPS   float64
	Burst int
}

func Load() Config {
	return Config{
		Server: ServerConfig{
			Addr:         getenv("ADDR", ":8080"),
			ReadTimeout:  mustDuration(getenv("READ_TIMEOUT", "30s")),
			WriteTimeout: mustDuration(getenv("WRITE_TIMEOUT", "0s")), // 0 = no hard cap; better for streaming
			IdleTimeout:  mustDuration(getenv("IDLE_TIMEOUT", "120s")),
		},
		Upstream: UpstreamConfig{
			BaseURL:           strings.TrimRight(getenv("UPSTREAM_BASE_URL", "https://api.openai.com"), "/"),
			APIKey:            getenv("UPSTREAM_API_KEY", ""),
			DefaultModel:      getenv("UPSTREAM_DEFAULT_MODEL", ""),
			APIKeyHeader:      getenv("UPSTREAM_API_KEY_HEADER", "Authorization"),
			RespectClientAuth: mustBool(getenv("RESPECT_CLIENT_AUTH", "false")),
		},
		LogRequests: mustBool(getenv("LOG_REQUESTS", "true")),
		LogLevel:    mustLogLevel(getenv("LOG_LEVEL", "info")),
		RPS:         mustFloat(getenv("RATE_LIMIT_RPS", "0")),
		Burst:       mustInt(getenv("RATE_LIMIT_BURST", "0")),
	}
}

func getenv(k, def string) string {
	v := strings.TrimSpace(os.Getenv(k))
	if v == "" {
		return def
	}
	return v
}

func mustDuration(s string) time.Duration {
	d, err := time.ParseDuration(strings.TrimSpace(s))
	if err != nil {
		return 30 * time.Second
	}
	return d
}

func mustBool(s string) bool {
	b, err := strconv.ParseBool(strings.TrimSpace(s))
	if err != nil {
		return false
	}
	return b
}

func mustInt(s string) int {
	i, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return 0
	}
	return i
}

func mustFloat(s string) float64 {
	f, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return 0
	}
	return f
}

func mustLogLevel(s string) slog.Level {
	s = strings.ToLower(strings.TrimSpace(s))
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
