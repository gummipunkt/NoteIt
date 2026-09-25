#!/usr/bin/env bash
# Runs the NoteItCore tests on Linux inside the official Swift Docker image.
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -v "$PWD":/src -w /src swift:6.2-noble swift test "$@"
