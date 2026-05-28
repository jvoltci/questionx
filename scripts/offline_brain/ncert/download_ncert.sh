#!/usr/bin/env bash
# Parallel curl downloader for NCERT PDFs. Replaces urllib version (got stuck).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/pdfs"
mkdir -p "$OUT"

UA='Mozilla/5.0 (compatible; questionx-offline-brain/0.1; +noncommercial-eval)'

# Build the code list (must match plan in download_ncert.py).
codes=()
for n in $(seq -w 01 15); do codes+=("class11_physics_p1:keph1${n}"); done
for n in $(seq -w 01 09); do codes+=("class11_physics_p2:keph2${n}"); done
for n in $(seq -w 01 09); do codes+=("class11_chemistry_p1:kech1${n}"); done
for n in $(seq -w 01 06); do codes+=("class11_chemistry_p2:kech2${n}"); done
for n in $(seq -w 01 22); do codes+=("class11_biology:kebo1${n}"); done
for n in $(seq -w 01 08); do codes+=("class12_physics_p1:leph1${n}"); done
for n in $(seq -w 01 08); do codes+=("class12_physics_p2:leph2${n}"); done
for n in $(seq -w 01 05); do codes+=("class12_chemistry_p1:lech1${n}"); done
for n in $(seq -w 01 10); do codes+=("class12_chemistry_p2:lech2${n}"); done
for n in $(seq -w 01 13); do codes+=("class12_biology:lebo1${n}"); done

ok=0
miss=0
for entry in "${codes[@]}"; do
  book="${entry%%:*}"
  code="${entry##*:}"
  out="$OUT/${book}__${code}.pdf"
  if [[ -s "$out" ]] && [[ $(stat -f%z "$out") -gt 10000 ]]; then
    ok=$((ok+1))
    continue
  fi
  url="https://ncert.nic.in/textbook/pdf/${code}.pdf"
  if curl -sfL --max-time 25 -A "$UA" -o "$out" "$url"; then
    sz=$(stat -f%z "$out" 2>/dev/null || echo 0)
    if [[ $sz -gt 10000 ]]; then
      printf "  ok    %-30s %d KB\n" "$book/$code" $((sz/1024))
      ok=$((ok+1))
    else
      rm -f "$out"
      printf "  tiny  %s\n" "$book/$code"
      miss=$((miss+1))
    fi
  else
    rm -f "$out"
    printf "  miss  %s\n" "$book/$code"
    miss=$((miss+1))
  fi
  sleep 0.25
done

printf "\ndone: %d ok, %d miss\n" "$ok" "$miss"
ls -1 "$OUT" | wc -l | awk '{print "files on disk:", $1}'
du -sh "$OUT"
