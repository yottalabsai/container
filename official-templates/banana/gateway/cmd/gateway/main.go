package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go-model-gateway/internal/config"
	"go-model-gateway/internal/proxy"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	slog.SetDefault(logger)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(cfg.Server.ReadTimeout))
	if cfg.LogRequests {
		r.Use(middleware.Logger)
	}

	// Liveness / readiness
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("content-type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true}`))
	})

	// OpenAI-compatible proxy endpoints (minimal set)
	px := proxy.New(cfg)

	// Chat Completions (supports stream via SSE)
	r.Post("/v1/chat/completions", px.HandlePassthrough())
	// Embeddings
	r.Post("/v1/embeddings", px.HandlePassthrough())
	// Responses (newer style, if your upstream supports it)
	r.Post("/v1/responses", px.HandlePassthrough())

	// Convenience alias (your own API surface)
	r.Route("/api", func(r chi.Router) {
		r.Post("/chat", px.HandlePassthrough())
		r.Post("/embeddings", px.HandlePassthrough())
	})

	srv := &http.Server{
		Addr:              cfg.Server.Addr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       cfg.Server.ReadTimeout,
		WriteTimeout:      cfg.Server.WriteTimeout,
		IdleTimeout:       cfg.Server.IdleTimeout,
	}

	errCh := make(chan error, 1)
	go func() {
		logger.Info("server starting", "addr", cfg.Server.Addr, "upstream", cfg.Upstream.BaseURL)
		errCh <- srv.ListenAndServe()
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-stop:
		logger.Info("shutdown signal", "signal", sig.String())
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server error", "err", err)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", "err", err)
		_ = srv.Close()
	}

	fmt.Println("bye")
}
