#!/bin/sh
# Install the qx-gate pre-commit hook into this repo's .git/hooks.
root="$(git rev-parse --show-toplevel)" || { echo "not a git repo"; exit 1; }
src="$root/scripts/qx_gate/hooks/pre-commit"
dst="$root/.git/hooks/pre-commit"
if [ -e "$dst" ]; then
  echo "A pre-commit hook already exists at $dst — not overwriting."
  echo "Append this line to it instead:  sh \"$src\""
  exit 1
fi
ln -s "$src" "$dst" 2>/dev/null || cp "$src" "$dst"
chmod +x "$dst"
echo "Installed qx-gate pre-commit hook -> $dst"
