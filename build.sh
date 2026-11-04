#!/usr/bin/env bash
# One command: ./build.sh 1.0.0 builds. ./build.sh 1.0.0 push also publishes.
set -euo pipefail
VERSION="${1:?Usage: ./build.sh VERSION [push]}"
IMAGE="${IMAGE:-localhost:5000/cloudnotes}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must look like 1.0.0"; exit 1
fi
docker build -t "$IMAGE:$VERSION" -t "$IMAGE:latest" .
if [[ "${2:-}" == "push" ]]; then
  docker push "$IMAGE:$VERSION"
  docker push "$IMAGE:latest"
fi
