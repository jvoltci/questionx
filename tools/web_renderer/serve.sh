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

# Use a custom handler that adds no-cache headers so Chrome always
# fetches the latest JSON / JS after a refresh.
python3 -c "
import http.server, functools

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

http.server.test(HandlerClass=NoCacheHandler, port=${PORT}, bind='')
"
