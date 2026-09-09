#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:?usage: vortex3d-benchmark.sh <source-dir>}"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
OUT_DIR="${RUNNER_TEMP:?}/vortex-benchmark-output"
mkdir -p "$OUT_DIR"

cd "$SOURCE_DIR"
test "$(git rev-parse HEAD)" = "${SOURCE_SHA:?}"

cmake -S . -B build-bench -DCMAKE_BUILD_TYPE=Release \
  -DVORTEX_BUILD_TESTS=OFF -DVORTEX_BUILD_BENCHMARKS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON >/dev/null
cmake --build build-bench --target vortex_mesh_bench vortex_eval_bench --parallel >/dev/null
./build-bench/vortex_mesh_bench --scale "$SCALE" --output "$OUT_DIR/benchmark-${SCALE}.json" >/dev/null
./build-bench/vortex_eval_bench --scale "$SCALE" --output "$OUT_DIR/evaluation-benchmark-${SCALE}.json" >/dev/null

printf 'source_sha=%s\nclient_id=%s\nbuilder_repo=%s\nbuilder_run_id=%s\nmode=benchmark\nscale=%s\n' \
  "$SOURCE_SHA" "${CLIENT_ID:-}" "${GITHUB_REPOSITORY:-}" "${GITHUB_RUN_ID:-}" "$SCALE" > "$OUT_DIR/provenance.txt"
sha256sum "$OUT_DIR"/*.json > "$OUT_DIR/sha256sums.txt"
