#!/usr/bin/env bash
#
# Compiles the pure-Dart chord analysis engine to JavaScript for the website
# chord-identification demo (docs/site/src/pages/try.astro).
#
# The output (docs/site/public/js/chord-id.js) is a generated artifact. Re-run
# this whenever the theory engine or tool/web/chord_id_main.dart changes.
#
# Usage:
#   tool/build_web_demo.sh
#   tool/build_web_demo.sh --check

set -euo pipefail

cd "$(dirname "$0")/.."

entry="tool/web/chord_id_main.dart"
out="docs/site/public/js/chord-id.js"
mode="${1:-build}"

mkdir -p "$(dirname "$out")"

if [[ "$mode" == "--check" ]]; then
  check_out=$(mktemp "${out}.check.XXXXXX")
  trap 'rm -f "$check_out" "$check_out.deps"' EXIT
  echo "Compiling $entry to verify $out"
  dart compile js "$entry" -o "$check_out" -O2 --no-source-maps
  rm -f "$check_out.deps"

  if ! cmp -s "$check_out" "$out"; then
    echo "$out is out of date; run tool/build_web_demo.sh" >&2
    exit 1
  fi

  echo "Verified. $out is current."
elif [[ "$mode" == "build" ]]; then
  echo "Compiling $entry -> $out"
  dart compile js "$entry" -o "$out" -O2 --no-source-maps

  # dart compile js emits a .deps sidecar we don't want to ship.
  rm -f "$out.deps"

  size=$(du -h "$out" | cut -f1)
  echo "Done. $out ($size)"
else
  echo "Usage: tool/build_web_demo.sh [--check]" >&2
  exit 2
fi
