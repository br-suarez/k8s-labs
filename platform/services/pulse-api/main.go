// Command pulse-api serves the Pulse check registry and results API.
//
// Module 01 ships it with an in-memory store and hand-rolled metrics on purpose:
// it builds with zero external dependencies, and later modules replace each piece
// deliberately (Postgres in 06, the Prometheus client in 07, OpenTelemetry in 08).
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

type Check struct {
	ID        string    `json:"id"`
	URL       string    `json:"url"`
	IntervalS int       `json:"interval_seconds"`
	CreatedAt time.Time `json:"created_at"`
}

type Result struct {
	CheckID    string    `json:"check_id"`
	StatusCode int       `json:"status_code"`
	LatencyMS  int64     `json:"latency_ms"`
	Error      string    `json:"error,omitempty"`
	ObservedAt time.Time `json:"observed_at"`
}

// store is the module 01 implementation. Module 06 swaps it for Postgres behind
// the same three methods, which is the point of keeping the surface this small.
type store struct {
	mu      sync.RWMutex
	checks  map[string]Check
	results []Result
	nextID  int
}

func newStore() *store {
	return &store{checks: make(map[string]Check), nextID: 1}
}

func (s *store) addCheck(url string, interval int) Check {
	s.mu.Lock()
	defer s.mu.Unlock()
	c := Check{
		ID:        fmt.Sprintf("chk-%03d", s.nextID),
		URL:       url,
		IntervalS: interval,
		CreatedAt: time.Now().UTC(),
	}
	s.checks[c.ID] = c
	s.nextID++
	return c
}

func (s *store) listChecks() []Check {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Check, 0, len(s.checks))
	for _, c := range s.checks {
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

func (s *store) addResult(r Result) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.results = append(s.results, r)
	// Bound the slice so a long-running dev instance cannot exhaust memory.
	if len(s.results) > 1000 {
		s.results = s.results[len(s.results)-1000:]
	}
}

func (s *store) listResults() []Result {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Result, len(s.results))
	copy(out, s.results)
	return out
}

// metrics is a minimal Prometheus text-format exporter. Module 07 replaces it
// with the official client library; writing it by hand first means you know what
// that library is actually producing.
type metrics struct {
	mu       sync.Mutex
	requests map[string]int64 // "method|path|status" -> count
	buckets  []float64
	latency  map[string]int64 // bucket upper bound -> cumulative count
	sum      float64
	count    int64
}

func newMetrics() *metrics {
	return &metrics{
		requests: make(map[string]int64),
		buckets:  []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5},
		latency:  make(map[string]int64),
	}
}

func (m *metrics) observe(method, path string, status int, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.requests[fmt.Sprintf("%s|%s|%d", method, path, status)]++
	secs := d.Seconds()
	for _, b := range m.buckets {
		if secs <= b {
			m.latency[fmt.Sprintf("%g", b)]++
		}
	}
	m.sum += secs
	m.count++
}

func (m *metrics) render() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := "# HELP pulse_http_requests_total Total HTTP requests.\n"
	out += "# TYPE pulse_http_requests_total counter\n"
	keys := make([]string, 0, len(m.requests))
	for k := range m.requests {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		parts := strings.SplitN(k, "|", 3)
		if len(parts) != 3 {
			continue
		}
		out += fmt.Sprintf("pulse_http_requests_total{method=%q,path=%q,status=%q} %d\n",
			parts[0], parts[1], parts[2], m.requests[k])
	}
	out += "# HELP pulse_http_request_duration_seconds Request latency.\n"
	out += "# TYPE pulse_http_request_duration_seconds histogram\n"
	for _, b := range m.buckets {
		out += fmt.Sprintf("pulse_http_request_duration_seconds_bucket{le=%q} %d\n",
			fmt.Sprintf("%g", b), m.latency[fmt.Sprintf("%g", b)])
	}
	out += fmt.Sprintf("pulse_http_request_duration_seconds_bucket{le=\"+Inf\"} %d\n", m.count)
	out += fmt.Sprintf("pulse_http_request_duration_seconds_sum %g\n", m.sum)
	out += fmt.Sprintf("pulse_http_request_duration_seconds_count %d\n", m.count)
	return out
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func instrument(m *metrics, path string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		h(sw, r)
		m.observe(r.Method, path, sw.status, time.Since(start))
	}
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	st := newStore()
	mx := newMetrics()

	// ready flips only once startup work is done. Module 04 wires it to a
	// readinessProbe, and module 11 relies on it to gate canary promotion.
	var ready bool
	var readyMu sync.RWMutex

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		readyMu.RLock()
		defer readyMu.RUnlock()
		if !ready {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "starting"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		fmt.Fprint(w, mx.render())
	})

	mux.HandleFunc("/api/checks", instrument(mx, "/api/checks", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, http.StatusOK, st.listChecks())
		case http.MethodPost:
			var body struct {
				URL       string `json:"url"`
				IntervalS int    `json:"interval_seconds"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.URL == "" {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "url is required"})
				return
			}
			if body.IntervalS <= 0 {
				body.IntervalS = 30
			}
			c := st.addCheck(body.URL, body.IntervalS)
			slog.Info("check created", "id", c.ID, "url", c.URL)
			writeJSON(w, http.StatusCreated, c)
		default:
			w.Header().Set("Allow", "GET, POST")
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		}
	}))

	mux.HandleFunc("/api/results", instrument(mx, "/api/results", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, http.StatusOK, st.listResults())
		case http.MethodPost:
			var res Result
			if err := json.NewDecoder(r.Body).Decode(&res); err != nil {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid result"})
				return
			}
			res.ObservedAt = time.Now().UTC()
			st.addResult(res)
			writeJSON(w, http.StatusAccepted, res)
		default:
			w.Header().Set("Allow", "GET, POST")
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		}
	}))

	addr := ":" + env("PORT", "8080")
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		// Stand-in for real startup work (migrations, cache warm). Module 06
		// replaces it with a genuine Postgres connection check.
		time.Sleep(2 * time.Second)
		readyMu.Lock()
		ready = true
		readyMu.Unlock()
		slog.Info("ready to serve traffic")
	}()

	go func() {
		slog.Info("pulse-api listening", "addr", addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server failed", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	// Graceful shutdown matters here: module 04 sets terminationGracePeriodSeconds
	// against it, and module 11 depends on it to drain during canary steps.
	slog.Info("shutting down")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("graceful shutdown failed", "err", err)
		os.Exit(1)
	}
	slog.Info("stopped cleanly")
}
