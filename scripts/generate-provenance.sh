#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-build-provenance.json}"
cat > "$OUT" <<EOF
{
  "builder": "VTXBuilder",
  "source_sha": "${GITHUB_SHA:-unknown}",
  "workflow": "${GITHUB_WORKFLOW:-manual}",
  "run_id": "${GITHUB_RUN_ID:-unknown}",
  "actor": "${GITHUB_ACTOR:-unknown}",
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "Generated $OUT"
