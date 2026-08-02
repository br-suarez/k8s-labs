// slo-demo is a deliberately controllable HTTP service used to practice
// SLI/SLO definition and error-budget burn-rate alerting.
//
// It exposes the two signals almost every request-driven SLO is built on:
//
//	http_requests_total{path,method,status}     -> availability SLI
//	http_request_duration_seconds{path,method}  -> latency SLI
//
// The /chaos endpoint mutates the service's behaviour at runtime so the error
// budget can be burned on demand without redeploying anything.
package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// behaviour holds the runtime knobs the /chaos endpoint writes to.
type behaviour struct {
	mu sync.RWMutex

	// errorRate is the probability [0,1] that /api answers 500.
	errorRate float64
	// slowRate is the probability [0,1] that /api takes a slow-path latency.
	slowRate float64
	// slowMinMS/slowMaxMS bound the slow path.
	slowMinMS int
	slowMaxMS int
}

func (b *behaviour) snapshot() (errorRate, slowRate float64, minMS, maxMS int) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.errorRate, b.slowRate, b.slowMinMS, b.slowMaxMS
}

// envFloat reads a probability from the environment, falling back to def.
// Used so a deliberately regressed build can be shipped as an image with a
// different baseline, which is what module 21 rolls out as a canary.
func envFloat(key string, def float64) float64 {
	v, ok := os.LookupEnv(key)
	if !ok {
		return def
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		log.Printf("ignoring invalid %s=%q: %v", key, v, err)
		return def
	}
	return clamp(f)
}

func envString(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

// appVersion is surfaced both in /api responses and as a metric label, so it is
// possible to tell which build served a request during a canary rollout.
var appVersion = envString("APP_VERSION", "v1")

// steady state: 0.1% errors and 0.5% slow requests.
// Both sit comfortably inside the SLOs defined in ../../slo/slo-definition.md,
// so a freshly started service is not burning budget. The defaults are the
// values module 20's evidence was captured with; the env vars only override.
var state = &behaviour{
	errorRate: envFloat("BASELINE_ERROR_RATE", 0.001),
	slowRate:  envFloat("BASELINE_SLOW_RATE", 0.005),
	slowMinMS: 320,
	slowMaxMS: 700,
}

var (
	// Buckets are chosen so that 0.3 is an exact boundary. The latency SLI is
	// "fraction of requests faster than 300ms", and a histogram can only answer
	// that exactly if 300ms is a real bucket edge — otherwise the query has to
	// interpolate and the SLI becomes an estimate.
	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request latency in seconds.",
		Buckets: []float64{0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2.5, 5},
	}, []string{"method", "path"})

	requestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests by method, path and response status code.",
	}, []string{"method", "path", "status"})

	// Deliberately a separate gauge rather than a label on the counters above:
	// putting the version on http_requests_total would change its label set on
	// every deploy, breaking rate() across the rollout boundary exactly when
	// the SLI matters most.
	buildInfo = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Name: "app_build_info",
		Help: "Always 1; the version label carries the running build.",
	}, []string{"version"})
)

// instrument wraps a handler so every request lands in both metrics.
func instrument(path string, next func(http.ResponseWriter, *http.Request) int) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		status := next(w, r)
		elapsed := time.Since(start).Seconds()

		requestDuration.WithLabelValues(r.Method, path).Observe(elapsed)
		requestsTotal.WithLabelValues(r.Method, path, strconv.Itoa(status)).Inc()
	}
}

// handleAPI is the endpoint the SLOs are defined against.
func handleAPI(w http.ResponseWriter, r *http.Request) int {
	errorRate, slowRate, slowMin, slowMax := state.snapshot()

	// Fast path: a normal request does 20-150ms of "work".
	delay := 20 + rand.Intn(130)
	if rand.Float64() < slowRate {
		delay = slowMin + rand.Intn(slowMax-slowMin+1)
	}
	time.Sleep(time.Duration(delay) * time.Millisecond)

	if rand.Float64() < errorRate {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return http.StatusInternalServerError
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"ok": true, "took_ms": delay, "version": appVersion})
	return http.StatusOK
}

// handleChaos reads or writes the runtime behaviour.
//
//	GET  /chaos
//	POST /chaos?error_rate=0.5&slow_rate=0.4
func handleChaos(w http.ResponseWriter, r *http.Request) int {
	if r.Method == http.MethodPost {
		q := r.URL.Query()
		state.mu.Lock()
		if v, err := strconv.ParseFloat(q.Get("error_rate"), 64); err == nil {
			state.errorRate = clamp(v)
		}
		if v, err := strconv.ParseFloat(q.Get("slow_rate"), 64); err == nil {
			state.slowRate = clamp(v)
		}
		state.mu.Unlock()
		log.Printf("chaos updated: error_rate=%v slow_rate=%v", q.Get("error_rate"), q.Get("slow_rate"))
	}

	errorRate, slowRate, slowMin, slowMax := state.snapshot()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"error_rate":  errorRate,
		"slow_rate":   slowRate,
		"slow_min_ms": slowMin,
		"slow_max_ms": slowMax,
	})
	return http.StatusOK
}

func clamp(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/api", instrument("/api", handleAPI))
	mux.HandleFunc("/chaos", instrument("/chaos", handleChaos))

	// /healthz is deliberately NOT instrumented. Kubernetes probes it every few
	// seconds and those requests are not user traffic — folding them into the
	// SLI would inflate the success ratio and hide real user-facing failures.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	mux.Handle("/metrics", promhttp.Handler())

	buildInfo.WithLabelValues(appVersion).Set(1)
	errorRate, slowRate, _, _ := state.snapshot()
	log.Printf("slo-demo version=%s baseline error_rate=%v slow_rate=%v", appVersion, errorRate, slowRate)

	log.Println("slo-demo listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatal(err)
	}
}
