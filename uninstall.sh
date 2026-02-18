#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
COMMANDS_DEST="$HOME/.claude/commands"

removed=0

for cmd_file in "$COMMANDS_SRC"/*.md; do
  [ -f "$cmd_file" ] || continue
  filename="$(basename "$cmd_file")"
  dest="$COMMANDS_DEST/$filename"

  if [ -L "$dest" ]; then
    rm "$dest"
    echo "  REMOVED  $filename"
    removed=$((removed + 1))
  fi
done

echo ""
echo "Done. $removed command(s) removed."
