#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:?usage: vortex3d-full.sh <source-dir>}"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
LOG_DIR="${RUNNER_TEMP:?}/vortex-private-logs"
OUT_DIR="${RUNNER_TEMP:?}/vortex-output"
mkdir -p "$LOG_DIR" "$OUT_DIR"

run_logged() {
  local name="$1"
  shift
  local log="$LOG_DIR/${name}.log"
  if ! "$@" >"$log" 2>&1; then
    echo "Stage failed: $name" >&2
    tail -n 100 "$log" >&2 || true
    return 1
  fi
}

bootstrap_deps() {
  local log="$LOG_DIR/dependencies.log"
  {
    echo "Preparing VTXBuilder build dependencies"
    if ! command -v glslc >/dev/null 2>&1; then
      echo "glslc is not preinstalled; installing from Ubuntu repositories"
      for source_file in /etc/apt/sources.list.d/*; do
        [ -f "$source_file" ] || continue
        if grep -q 'dl.google.com/linux/chrome' "$source_file"; then
          sudo rm -f "$source_file"
        fi
      done

      apt_ready=false
      for attempt in 1 2 3; do
        sudo rm -rf /var/lib/apt/lists/*
        if sudo apt-get update -o Acquire::Retries=3; then
          apt_ready=true
          break
        fi
        sleep $((attempt * 5))
      done
      [ "$apt_ready" = true ] || {
        echo "Ubuntu apt metadata could not be refreshed after 3 attempts"
        return 1
      }
      sudo apt-get install -y --no-install-recommends glslc
    fi

    glslc --version
    test -f "$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
  } >"$log" 2>&1 || {
    echo "Worker dependency bootstrap failed" >&2
    tail -n 100 "$log" >&2 || true
    return 1
  }
}

cd "$SOURCE_DIR"
test "$(git rev-parse HEAD)" = "${SOURCE_SHA:?}"
test -f CMakeLists.txt
test -f android/app/build.gradle
echo "Building private Vortex3D $SOURCE_SHA for client ${CLIENT_ID:-unknown}"

bootstrap_deps

# VTXBuilder is an artifact builder, not a second validation framework.
# Deep subsystem validation/diagnostics live with Vortex3D and run in the app.
# Keep only fast source hygiene checks here before producing Android artifacts.
run_logged repository-policy python3 scripts/check_repository_policy.py
run_logged portable-boundary python3 scripts/check_core_portability.py

# Gradle/CMake is the single Android compile path. It owns the configured ARM32,
# ARM64, split, and universal outputs, avoiding duplicate native rebuilds here.
run_logged android-apk-build gradle -p android :app:assembleDebug --no-daemon

run_logged apk-verify python3 tools/diagnostics/apk_verify.py \
  --input-dir android/app/build/outputs/apk/debug \
  --output-dir apk-artifacts \
  --manifest apk-artifacts/apk-manifest.json

SHORT_SHA="${SOURCE_SHA:0:8}"
cp apk-artifacts/*.apk "$OUT_DIR/"
cp apk-artifacts/apk-manifest.json "$OUT_DIR/"
printf 'source_sha=%s\nclient_id=%s\nbuilder_repo=%s\nbuilder_run_id=%s\nmode=full\n' \
  "$SOURCE_SHA" "${CLIENT_ID:-}" "${GITHUB_REPOSITORY:-}" "${GITHUB_RUN_ID:-}" > "$OUT_DIR/provenance.txt"

echo "Vortex3D Android build completed for $SOURCE_SHA"
