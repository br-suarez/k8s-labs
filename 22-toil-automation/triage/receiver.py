#!/usr/bin/env python3
"""Alertmanager webhook receiver that runs the triage runbook automatically.

Alertmanager POSTs a JSON payload here the moment an alert fires. Each firing
alert triggers triage.sh, and the report is written to disk and to stdout (so
`kubectl logs` shows it) before a human has opened anything.

Standard library only — no Flask, no requests. A tool that runs during an
incident should have as few moving parts as possible; a dependency that fails to
install is one more thing broken at 3am.
"""
import json
import os
import subprocess
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPORT_DIR = os.environ.get("REPORT_DIR", "/reports")
TRIAGE = os.environ.get("TRIAGE_SCRIPT", "/app/triage.sh")
PORT = int(os.environ.get("PORT", "9000"))

# Triage runs in a worker thread; Alertmanager expects a fast 200 and will
# retry the whole batch if the handler blocks for the length of a kubectl run.
_lock = threading.Lock()


def now():
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def log(msg):
    print(f"[{now()}] {msg}", flush=True)


def run_triage(alertname, service, namespace):
    started = datetime.now(timezone.utc)
    log(f"running triage for alert={alertname} service={service} ns={namespace}")
    try:
        out = subprocess.run(
            [TRIAGE, service, namespace],
            capture_output=True, text=True, timeout=120,
        )
        body = out.stdout + (("\nSTDERR:\n" + out.stderr) if out.stderr.strip() else "")
    except subprocess.TimeoutExpired:
        body = "TRIAGE TIMED OUT after 120s"
    elapsed = (datetime.now(timezone.utc) - started).total_seconds()

    header = (
        f"alert:      {alertname}\n"
        f"service:    {service}\n"
        f"namespace:  {namespace}\n"
        f"triggered:  {started.isoformat()}\n"
        f"duration:   {elapsed:.2f}s\n\n"
    )

    os.makedirs(REPORT_DIR, exist_ok=True)
    path = os.path.join(REPORT_DIR, f"{now()}-{alertname}.txt")
    with _lock:
        with open(path, "w") as f:
            f.write(header + body)
    log(f"triage complete in {elapsed:.2f}s -> {path}")
    print(header + body, flush=True)


class Handler(BaseHTTPRequestHandler):
    # Silence the default per-request stderr logging; we do our own.
    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        if self.path in ("/healthz", "/"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)

        # Respond immediately, then work. Alertmanager's webhook timeout is
        # shorter than a full triage run.
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"accepted")

        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as e:
            log(f"bad payload: {e}")
            return

        alerts = payload.get("alerts", [])
        log(f"received {len(alerts)} alert(s), status={payload.get('status')}")

        for alert in alerts:
            if alert.get("status") != "firing":
                continue
            labels = alert.get("labels", {})
            threading.Thread(
                target=run_triage,
                args=(
                    labels.get("alertname", "unknown"),
                    labels.get("service", "slo-demo"),
                    labels.get("namespace", "slo-demo"),
                ),
                daemon=True,
            ).start()


if __name__ == "__main__":
    log(f"triage receiver listening on :{PORT}, reports -> {REPORT_DIR}")
    try:
        ThreadingHTTPServer(("", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
