// Command pulse-worker probes the endpoints registered in pulse-api and reports
// the results back.
//
// The internal job queue is deliberately bounded and its depth is exported as a
// metric. Queue depth is the saturation signal the observability modules build
// their SLO on, and a bounded queue is what makes backpressure observable instead
// of turning into unbounded memory growth.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

type Check struct {
	ID        string `json:"id"`
	URL       string `json:"url"`
	IntervalS int    `json:"interval_seconds"`
}

type Result struct {
	CheckID    string `json:"check_id"`
	StatusCode int    `json:"status_code"`
	LatencyMS  int64  `json:"latency_ms"`
	Error      string `json:"error,omitempty"`
}

type counters struct {
	probesTotal   atomic.Int64
	probeFailures atomic.Int64
	queueDepth    atomic.Int64
	queueDropped  atomic.Int64
}

func (c *counters) render(workers int) string {
	var b bytes.Buffer
	fmt.Fprint(&b, "# HELP pulse_worker_probes_total Probes executed.\n")
	fmt.Fprint(&b, "# TYPE pulse_worker_probes_total counter\n")
	fmt.Fprintf(&b, "pulse_worker_probes_total %d\n", c.probesTotal.Load())

	fmt.Fprint(&b, "# HELP pulse_worker_probe_failures_total Probes that returned an error or non-2xx.\n")
	fmt.Fprint(&b, "# TYPE pulse_worker_probe_failures_total counter\n")
	fmt.Fprintf(&b, "pulse_worker_probe_failures_total %d\n", c.probeFailures.Load())

	// The saturation signal. Module 07 alerts on this, module 08 correlates it
	// with traces, and module 11 uses it as a canary rejection criterion.
	fmt.Fprint(&b, "# HELP pulse_worker_queue_depth Jobs waiting to be probed.\n")
	fmt.Fprint(&b, "# TYPE pulse_worker_queue_depth gauge\n")
	fmt.Fprintf(&b, "pulse_worker_queue_depth %d\n", c.queueDepth.Load())

	fmt.Fprint(&b, "# HELP pulse_worker_queue_dropped_total Jobs dropped because the queue was full.\n")
	fmt.Fprint(&b, "# TYPE pulse_worker_queue_dropped_total counter\n")
	fmt.Fprintf(&b, "pulse_worker_queue_dropped_total %d\n", c.queueDropped.Load())

	fmt.Fprint(&b, "# HELP pulse_worker_concurrency Configured worker goroutines.\n")
	fmt.Fprint(&b, "# TYPE pulse_worker_concurrency gauge\n")
	fmt.Fprintf(&b, "pulse_worker_concurrency %d\n", workers)
	return b.String()
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
		slog.Warn("invalid integer in environment, using default", "key", key, "value", v, "default", def)
	}
	return def
}

type worker struct {
	apiBase string
	client  *http.Client
	jobs    chan Check
	c       *counters
}

func (w *worker) fetchChecks(ctx context.Context) ([]Check, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, w.apiBase+"/api/checks", nil)
	if err != nil {
		return nil, err
	}
	resp, err := w.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %d from checks API", resp.StatusCode)
	}
	var checks []Check
	if err := json.NewDecoder(resp.Body).Decode(&checks); err != nil {
		return nil, err
	}
	return checks, nil
}

func (w *worker) probe(ctx context.Context, c Check) Result {
	res := Result{CheckID: c.ID}
	start := time.Now()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.URL, nil)
	if err != nil {
		res.Error = err.Error()
		return res
	}
	resp, err := w.client.Do(req)
	res.LatencyMS = time.Since(start).Milliseconds()
	if err != nil {
		res.Error = err.Error()
		return res
	}
	defer resp.Body.Close()
	res.StatusCode = resp.StatusCode
	return res
}

func (w *worker) report(ctx context.Context, r Result) error {
	body, err := json.Marshal(r)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, w.apiBase+"/api/results", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := w.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("results API returned %d", resp.StatusCode)
	}
	return nil
}

func (w *worker) run(ctx context.Context, id int, wg *sync.WaitGroup) {
	defer wg.Done()
	for {
		select {
		case <-ctx.Done():
			slog.Info("worker stopping", "worker", id)
			return
		case job, ok := <-w.jobs:
			if !ok {
				return
			}
			w.c.queueDepth.Add(-1)
			res := w.probe(ctx, job)
			w.c.probesTotal.Add(1)
			if res.Error != "" || res.StatusCode < 200 || res.StatusCode >= 300 {
				w.c.probeFailures.Add(1)
				slog.Warn("probe failed",
					"check", job.ID, "url", job.URL,
					"status", res.StatusCode, "err", res.Error)
			}
			if err := w.report(ctx, res); err != nil && ctx.Err() == nil {
				slog.Error("could not report result", "check", job.ID, "err", err)
			}
		}
	}
}

// enqueue never blocks. A full queue drops the job and increments a counter,
// which is what makes saturation visible rather than silently turning into
// latency somewhere further upstream.
func (w *worker) enqueue(c Check) {
	select {
	case w.jobs <- c:
		w.c.queueDepth.Add(1)
	default:
		w.c.queueDropped.Add(1)
		slog.Warn("queue full, dropping job", "check", c.ID)
	}
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	var (
		apiBase   = env("PULSE_API_URL", "http://localhost:8080")
		workers   = envInt("WORKER_CONCURRENCY", 4)
		queueSize = envInt("QUEUE_SIZE", 64)
		tickS     = envInt("SCHEDULE_INTERVAL_SECONDS", 15)
		port      = env("PORT", "8081")
	)

	c := &counters{}
	w := &worker{
		apiBase: apiBase,
		client:  &http.Client{Timeout: 10 * time.Second},
		jobs:    make(chan Check, queueSize),
		c:       c,
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	for i := 1; i <= workers; i++ {
		wg.Add(1)
		go w.run(ctx, i, &wg)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(rw http.ResponseWriter, _ *http.Request) {
		rw.WriteHeader(http.StatusOK)
		fmt.Fprint(rw, `{"status":"ok"}`)
	})
	mux.HandleFunc("/metrics", func(rw http.ResponseWriter, _ *http.Request) {
		rw.Header().Set("Content-Type", "text/plain; version=0.0.4")
		fmt.Fprint(rw, c.render(workers))
	})

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		slog.Info("pulse-worker metrics listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("metrics server failed", "err", err)
		}
	}()

	ticker := time.NewTicker(time.Duration(tickS) * time.Second)
	defer ticker.Stop()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	slog.Info("pulse-worker started",
		"api", apiBase, "workers", workers, "queue_size", queueSize, "interval_s", tickS)

	for {
		select {
		case <-stop:
			slog.Info("shutting down")
			cancel()

			shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer shutdownCancel()
			if err := srv.Shutdown(shutdownCtx); err != nil {
				slog.Error("metrics server shutdown failed", "err", err)
			}

			done := make(chan struct{})
			go func() { wg.Wait(); close(done) }()
			select {
			case <-done:
				slog.Info("stopped cleanly")
			case <-time.After(15 * time.Second):
				slog.Warn("workers did not drain in time")
			}
			return

		case <-ticker.C:
			checks, err := w.fetchChecks(ctx)
			if err != nil {
				slog.Error("could not fetch checks", "err", err)
				continue
			}
			for _, chk := range checks {
				w.enqueue(chk)
			}
			slog.Info("scheduled probes", "count", len(checks), "queue_depth", c.queueDepth.Load())
		}
	}
}
