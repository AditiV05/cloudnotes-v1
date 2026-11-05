"""Structured logging: one JSON object per line, with a request_id on every line."""
import json
import logging
import os
import re
import sys
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, g, has_request_context, request

SAFE_REQUEST_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
QUIET_PATHS = {"/metrics", "/health", "/ready"}  # scrapes and probes are not user traffic


class JsonFormatter(logging.Formatter):
    def format(self, record):
        line = {
            "timestamp": datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"),
            "level": record.levelname,
            "request_id": g.get("request_id", "-") if has_request_context() else "-",
            "message": record.getMessage(),
        }
        line.update(getattr(record, "fields", {}))
        if record.exc_info:
            line["exception"] = self.formatException(record.exc_info)
        return json.dumps(line)


def configure_logging() -> None:
    """Write JSON to stdout. LOG_FILE also writes a copy, for a shipper that tails a file."""
    handlers = [logging.StreamHandler(sys.stdout)]
    if os.environ.get("LOG_FILE"):
        handlers.append(logging.FileHandler(os.environ["LOG_FILE"]))
    for handler in handlers:
        handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = handlers
    root.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())


def init_request_logging(app: Flask) -> None:
    @app.before_request
    def start_request_log():
        supplied = request.headers.get("X-Request-ID", "")
        g.request_id = supplied if SAFE_REQUEST_ID.match(supplied) else uuid.uuid4().hex[:12]
        g.log_started = time.perf_counter()
        if request.path not in QUIET_PATHS:
            app.logger.info("request received", extra={"fields": {"method": request.method, "path": request.path}})

    @app.after_request
    def finish_request_log(response):
        response.headers["X-Request-ID"] = g.request_id
        if request.path not in QUIET_PATHS:
            level = logging.ERROR if response.status_code >= 500 else logging.INFO
            duration_ms = round((time.perf_counter() - g.log_started) * 1000, 2)
            app.logger.log(level, "request completed", extra={"fields": {
                "method": request.method, "path": request.path,
                "status": response.status_code, "duration_ms": duration_ms,
            }})
        return response
