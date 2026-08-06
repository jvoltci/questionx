#!/usr/bin/env bash
# Retry the books whose seq -w padding silently broke in download_ncert.sh
# (macOS BSD seq -w doesn't pad single-digit ranges; codes ended up 4-char).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/pdfs"
mkdir -p "$OUT"
UA='Mozilla/5.0 (compatible; questionx-offline-brain/0.1)'

# All books that need re-attempting with proper 3-digit suffix codes.
declare -a books=(
  "class11_chemistry_p1 kech1 9"
  "class11_chemistry_p2 kech2 6"
  "class11_physics_p2   keph2 9"
  "class12_chemistry_p1 lech1 5"
  "class12_physics_p1   leph1 8"
  "class12_physics_p2   leph2 8"
)

ok=0
miss=0
for entry in "${books[@]}"; do
  read -r book prefix maxn <<<"$entry"
  for n in $(seq 1 "$maxn"); do
    code=$(printf "%s%02d" "$prefix" "$n")
    out="$OUT/${book}__${code}.pdf"
    if [[ -s "$out" ]] && [[ $(stat -f%z "$out") -gt 10000 ]]; then
      ok=$((ok+1)); continue
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
    sleep 0.2
  done
done

printf "\ndone: %d ok, %d miss\n" "$ok" "$miss"
ls -1 "$OUT" | wc -l | awk '{print "files on disk:", $1}'
du -sh "$OUT"
