#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
exec python3 serve.py "${1:-8787}"
