#!/usr/bin/env bash
# Render the real PDF-export HTML for given question ids through headless Chrome
# and open the result. Run this before shipping ANY change that touches
# lib/services/pdf_service.dart or lib/services/latex_to_html.dart.
#
#   tool/render_check.sh JEE_Adv_2017_P2_Phy_5,JEE_Main_2026_Jan24_S1_Phy_9
#
# Android's print WebView is Blink with JavaScript disabled, so headless Chrome
# printing plain HTML is a faithful proxy for what the student gets.
set -euo pipefail
IDS="${1:?usage: tool/render_check.sh <id,id,...>}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=/tmp/qx_render
QX_IDS="$IDS" flutter test test/render_dump_test.dart >/dev/null
"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$OUT.pdf" "file://$OUT.html" >/dev/null 2>&1
rm -f "$OUT"-*.png
pdftoppm -r 110 -png "$OUT.pdf" "$OUT"
echo "rendered: $(ls "$OUT"-*.png | tr '\n' ' ')"
open "$OUT"-1.png 2>/dev/null || true
