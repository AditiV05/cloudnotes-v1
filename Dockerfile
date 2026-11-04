# ---------- Stage 1: BUILD (heavy, thrown away) ----------
FROM python:3.11-slim-bookworm AS build
WORKDIR /build

# Install only the runtime dependencies into one folder.
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/build/deps -r requirements.txt

# Prepare the app files the runtime needs, and nothing else.
COPY app.py ./app/
COPY api ./app/api
COPY utils ./app/utils
COPY templates ./app/templates
COPY static ./app/static
RUN mkdir -p /build/app/database /build/app/uploads

# ---------- Stage 2: RUNTIME (slim, this is what ships) ----------
# Distroless has Python but no shell, no pip, and no apt. It runs as non-root.
FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app

# Only these two lines bring anything from the build stage.
COPY --from=build --chown=65532:65532 /build/deps /app/deps
COPY --from=build --chown=65532:65532 /build/app /app

ENV PYTHONPATH=/app/deps
ENV PYTHONUNBUFFERED=1
EXPOSE 5000

# The base image already runs python3, so these are its arguments.
CMD ["-m", "gunicorn", "--workers", "2", "--bind", "0.0.0.0:5000", "--worker-tmp-dir", "/dev/shm", "app:app"]
