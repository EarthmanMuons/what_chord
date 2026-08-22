#!/usr/bin/env bash
# Run the frozen automatic-polychord product-path performance benchmark.
set -euo pipefail

cd "$(dirname "$0")/.."

for arg in "$@"; do
  case "$arg" in
    -h|--help|--validate-only)
      exec dart run --verbosity=error benchmark/polychord_benchmark.dart "$@"
      ;;
  esac
done

exec dart run \
  --verbosity=error \
  --enable-vm-service \
  benchmark/polychord_benchmark.dart "$@"
