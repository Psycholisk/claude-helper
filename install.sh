#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
COMMANDS_DEST="$HOME/.claude/commands"

# Ensure target directory exists
mkdir -p "$COMMANDS_DEST"

installed=0
skipped=0

for cmd_file in "$COMMANDS_SRC"/*.md; do
  [ -f "$cmd_file" ] || continue
  filename="$(basename "$cmd_file")"
  dest="$COMMANDS_DEST/$filename"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP  $filename (file already exists and is not a symlink)"
    skipped=$((skipped + 1))
    continue
  fi

  ln -sf "$cmd_file" "$dest"
  echo "  LINK  $filename -> $dest"
  installed=$((installed + 1))
done

echo ""
echo "Done. $installed command(s) installed, $skipped skipped."
echo "Commands are available as /command-name in Claude Code."
