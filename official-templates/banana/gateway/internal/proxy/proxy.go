package proxy

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"go-model-gateway/internal/config"
	"go-model-gateway/internal/httpx"

	"golang.org/x/time/rate"
)

type Proxy struct {
	cfg    config.Config
	client *http.Client
	lim    *rate.Limiter
}

func New(cfg config.Config) *Proxy {
	// 0 timeout keeps streaming connections alive; we still use server-level idle/write timeouts.
	cliTimeout := 0 * time.Second
	p := &Proxy{cfg: cfg, client: httpx.New(cliTimeout)}
	if cfg.RPS > 0 {
		burst := cfg.Burst
		if burst <= 0 {
			burst = int(cfg.RPS)
			if burst < 1 {
				burst = 1
			}
		}
		p.lim = rate.NewLimiter(rate.Limit(cfg.RPS), burst)
	}
	return p
}

// HandlePassthrough forwards the incoming OpenAI-style request body to upstream,
// preserving streaming (SSE) if the upstream responds as event-stream.
func (p *Proxy) HandlePassthrough() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if p.lim != nil {
			if !p.lim.Allow() {
				writeJSON(w, http.StatusTooManyRequests, map[string]any{"error": "rate_limited"})
				return
			}
		}

		upURL, err := p.upstreamURL(r.URL.Path)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "bad_upstream_url", "detail": err.Error()})
			return
		}

		bodyBytes, err := io.ReadAll(io.LimitReader(r.Body, 20<<20)) // 20MB cap; adjust as needed
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "read_body_failed"})
			return
		}
		_ = r.Body.Close()

		// Optionally enforce default model if client didn't provide one.
		if p.cfg.Upstream.DefaultModel != "" {
			bodyBytes = maybeInjectDefaultModel(bodyBytes, p.cfg.Upstream.DefaultModel)
		}

		req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, upURL.String(), bytes.NewReader(bodyBytes))
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "new_request_failed"})
			return
		}

		copyHeadersForUpstream(req.Header, r.Header)
		req.Header.Set("content-type", "application/json")

		// Inject auth if needed.
		p.applyAuth(req, r)

		start := time.Now()
		resp, err := p.client.Do(req)
		if err != nil {
			// Context cancellation is common for streaming.
			if errors.Is(err, context.Canceled) {
				return
			}
			slog.Error("upstream request failed", "err", err, "path", r.URL.Path)
			writeJSON(w, http.StatusBadGateway, map[string]any{"error": "upstream_failed", "detail": err.Error()})
			return
		}
		defer resp.Body.Close()

		// Propagate status & headers.
		for k, vv := range resp.Header {
			// Some hop-by-hop headers should not be forwarded.
			if isHopByHopHeader(k) {
				continue
			}
			for _, v := range vv {
				w.Header().Add(k, v)
			}
		}
		w.WriteHeader(resp.StatusCode)

		// Streaming: just copy bytes through.
		// For non-streaming: also copy bytes through.
		if fl, ok := w.(http.Flusher); ok {
			buf := make([]byte, 32*1024)
			for {
				n, rerr := resp.Body.Read(buf)
				if n > 0 {
					_, _ = w.Write(buf[:n])
					fl.Flush()
				}
				if rerr != nil {
					break
				}
			}
		} else {
			_, _ = io.Copy(w, resp.Body)
		}

		slog.Info("proxied", "path", r.URL.Path, "status", resp.StatusCode, "ms", time.Since(start).Milliseconds())
	}
}

func (p *Proxy) upstreamURL(path string) (*url.URL, error) {
	base, err := url.Parse(p.cfg.Upstream.BaseURL)
	if err != nil {
		return nil, err
	}
	// Ensure base has no trailing slash (done in cfg), join path.
	base.Path = strings.TrimRight(base.Path, "/") + path
	return base, nil
}

func (p *Proxy) applyAuth(req *http.Request, clientReq *http.Request) {
	if p.cfg.Upstream.RespectClientAuth {
		if clientReq.Header.Get("Authorization") != "" {
			return
		}
	}
	if p.cfg.Upstream.APIKey == "" {
		return
	}
	h := p.cfg.Upstream.APIKeyHeader
	if strings.EqualFold(h, "authorization") {
		req.Header.Set("Authorization", "Bearer "+p.cfg.Upstream.APIKey)
		return
	}
	req.Header.Set(h, p.cfg.Upstream.APIKey)
}

func copyHeadersForUpstream(dst, src http.Header) {
	for k, vv := range src {
		if isHopByHopHeader(k) {
			continue
		}
		// Do not forward Host.
		if strings.EqualFold(k, "host") {
			continue
		}
		for _, v := range vv {
			dst.Add(k, v)
		}
	}
}

func isHopByHopHeader(k string) bool {
	k = strings.ToLower(strings.TrimSpace(k))
	switch k {
	case "connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade":
		return true
	default:
		return false
	}
}

// maybeInjectDefaultModel tries to set {"model": <default>} if absent.
// If body isn't JSON object, returns original.
func maybeInjectDefaultModel(body []byte, defModel string) []byte {
	var m map[string]any
	if err := json.Unmarshal(body, &m); err != nil {
		return body
	}
	if _, ok := m["model"]; ok {
		return body
	}
	m["model"] = defModel
	out, err := json.Marshal(m)
	if err != nil {
		return body
	}
	return out
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("content-type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
