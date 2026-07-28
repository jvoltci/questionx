#!/usr/bin/env bash
# Serve the QuestionX render-check page from the repo root so the page can
# reach both assets/jee.json and scripts/jee/out/full/diagrams_jee_clean/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${1:-8001}"
cd "$ROOT"
echo "QuestionX render check"
echo "  serving repo root: $ROOT"
echo "  open → http://localhost:${PORT}/tools/web_renderer/"
echo "  (Ctrl-C to stop)"
exec python3 -m http.server "$PORT"
