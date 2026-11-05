"""Prometheus metrics for the request path: traffic, errors and latency."""
import time

from flask import Flask, Response, g, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests served.",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path"],
)


def init_metrics(app: Flask) -> None:
    @app.before_request
    def start_timer():
        g.request_started = time.perf_counter()

    @app.after_request
    def record(response):
        if request.path == "/metrics":
            return response  # scrapes are not user traffic
        # Use the route pattern, not the raw URL, so labels stay few.
        path = request.url_rule.rule if request.url_rule else "unmatched"
        REQUESTS.labels(request.method, path, str(response.status_code)).inc()
        LATENCY.labels(request.method, path).observe(time.perf_counter() - g.request_started)
        return response

    @app.route("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
