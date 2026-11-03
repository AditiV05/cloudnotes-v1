#!/usr/bin/env bash
# Run Terraform from Docker so nothing needs installing:  ./tf.sh init | validate | plan
# (Equivalent to the `terraform` command. Never run apply in this assignment.)
if [[ "${1:-}" == "apply" ]]; then echo "apply is disabled: this assignment stops at plan (zero cost)."; exit 1; fi
exec docker run --rm -it -v "$PWD":/workspace -w /workspace hashicorp/terraform:latest "$@"
