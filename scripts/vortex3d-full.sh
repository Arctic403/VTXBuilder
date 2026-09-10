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
    echo "Preparing VTXBuilder dependencies"
    if ! command -v glslc >/dev/null 2>&1; then
      echo "glslc is not preinstalled; installing from Ubuntu repositories"
      for source_file in /etc/apt/sources.list.d/*; do
        [ -f "$source_file" ] || continue
        if grep -q 'dl.google.com/linux/chrome' "$source_file"; then
          echo "Disabling unrelated Chrome apt source: $source_file"
          sudo rm -f "$source_file"
        fi
      done

      apt_ready=false
      for attempt in 1 2 3; do
        echo "apt metadata refresh attempt $attempt/3"
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
    else
      echo "Using preinstalled glslc: $(command -v glslc)"
    fi

    glslc --version
    clang-tidy --version | head -n 1
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

# VTXBuilder owns heavy verification. Keep source-repo coupling limited to stable,
# maintained checks and build/test entry points.
run_logged repository-policy python3 scripts/check_repository_policy.py
run_logged portable-boundary python3 scripts/check_core_portability.py

export CXX=g++
run_logged linux-gcc bash -lc '
  cmake -S . -B build-gcc -DCMAKE_BUILD_TYPE=Debug -DVORTEX_BUILD_TESTS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON &&
  cmake --build build-gcc --config Debug --parallel &&
  ctest --test-dir build-gcc --output-on-failure
'

export CXX=clang++
run_logged linux-clang bash -lc '
  cmake -S . -B build-clang -DCMAKE_BUILD_TYPE=Debug -DVORTEX_BUILD_TESTS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON &&
  cmake --build build-clang --config Debug --parallel &&
  ctest --test-dir build-clang --output-on-failure
'

ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 \
UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
run_logged sanitizers bash -lc '
  cmake -S . -B build-sanitize -DCMAKE_BUILD_TYPE=Debug -DVORTEX_BUILD_TESTS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" &&
  cmake --build build-sanitize --parallel &&
  ctest --test-dir build-sanitize --output-on-failure
'

run_logged static-analysis bash -lc '
  cmake -S . -B build-tidy -DCMAKE_BUILD_TYPE=Debug -DVORTEX_BUILD_TESTS=OFF -DCMAKE_EXPORT_COMPILE_COMMANDS=ON &&
  mapfile -t SOURCES < <(find src -name "*.cpp" -print | sort) &&
  clang-tidy "${SOURCES[@]}" -p build-tidy --quiet --warnings-as-errors="bugprone-*,performance-*,portability-*"
'

run_logged vss bash -lc '
  cmake -S . -B build-vss -DCMAKE_BUILD_TYPE=Debug -DVORTEX_BUILD_TESTS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON &&
  cmake --build build-vss --parallel &&
  python3 tools/vss/verify.py --build-dir build-vss --out vss-artifacts/vss.json --summary vss-artifacts/vss-summary.txt
'

run_logged android-arm32 bash -lc '
  cmake -S android/app/src/main/cpp -B build-android-armeabi-v7a -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DVORTEX_BUILD_TESTS=OFF \
    -DVORTEX_WARNINGS_AS_ERRORS=ON -DVORTEX_EXPECT_POINTER_BITS=32 &&
  cmake --build build-android-armeabi-v7a --target vortex_android --parallel
'

run_logged android-arm64 bash -lc '
  cmake -S android/app/src/main/cpp -B build-android-arm64-v8a -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DVORTEX_BUILD_TESTS=OFF \
    -DVORTEX_WARNINGS_AS_ERRORS=ON -DVORTEX_EXPECT_POINTER_BITS=64 &&
  cmake --build build-android-arm64-v8a --target vortex_android --parallel
'

run_logged android-apk-build gradle -p android :app:assembleDebug --no-daemon
run_logged apk-verify python3 tools/diagnostics/apk_verify.py \
  --input-dir android/app/build/outputs/apk/debug \
  --output-dir apk-artifacts \
  --manifest apk-artifacts/apk-manifest.json

run_logged performance-smoke bash -lc '
  cmake -S . -B build-bench -DCMAKE_BUILD_TYPE=Release -DVORTEX_BUILD_TESTS=OFF \
    -DVORTEX_BUILD_BENCHMARKS=ON -DVORTEX_WARNINGS_AS_ERRORS=ON &&
  cmake --build build-bench --target vortex_mesh_bench vortex_eval_bench --parallel &&
  ./build-bench/vortex_mesh_bench --smoke --output benchmark-smoke.json &&
  ./build-bench/vortex_eval_bench --smoke --output evaluation-benchmark-smoke.json
'

mkdir -p verification-input/vss verification-input/apks \
  verification-input/benchmarks verification-input/logs verification-bundle
cp vss-artifacts/* verification-input/vss/
cp apk-artifacts/* verification-input/apks/
cp benchmark-smoke.json evaluation-benchmark-smoke.json verification-input/benchmarks/
cp "$LOG_DIR"/*.log verification-input/logs/
run_logged diagnostics-bundle env GITHUB_SHA="$SOURCE_SHA" python3 tools/diagnostics/build_report.py \
  --input-dir verification-input --output-dir verification-bundle

SHORT_SHA="${SOURCE_SHA:0:8}"
cp apk-artifacts/*.apk "$OUT_DIR/"
cp apk-artifacts/apk-manifest.json verification-bundle/diagnostics.json "$OUT_DIR/"
printf 'source_sha=%s\nclient_id=%s\nbuilder_repo=%s\nbuilder_run_id=%s\nmode=full\n' \
  "$SOURCE_SHA" "${CLIENT_ID:-}" "${GITHUB_REPOSITORY:-}" "${GITHUB_RUN_ID:-}" > "$OUT_DIR/provenance.txt"
(cd verification-input && zip -qr "$OUT_DIR/Vortex3D-verification-${SHORT_SHA}.zip" .)

echo "Vortex3D full verification completed for $SOURCE_SHA"
