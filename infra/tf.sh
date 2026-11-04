#!/usr/bin/env bash
# Runs Terraform in Docker: ./tf.sh init | validate | plan
# Zero cost: this capstone stops at plan, so apply is blocked.
if [[ "${1:-}" == "apply" ]]; then echo "apply is disabled: this capstone stops at plan."; exit 1; fi
TTY=""; [[ -t 1 ]] && TTY="-t"
exec docker run --rm -i $TTY --add-host=host.docker.internal:host-gateway -v "$PWD":/workspace -w /workspace hashicorp/terraform:latest "$@"
