#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
COMMANDS_DEST="$HOME/.claude/commands"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

# Ensure target directories exist
mkdir -p "$COMMANDS_DEST" "$SKILLS_DEST"

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

# Skills are directories (SKILL.md + supporting files); symlink the whole dir.
skills_installed=0
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dest="$SKILLS_DEST/$skill_name"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP  $skill_name/ (directory already exists and is not a symlink)"
    skipped=$((skipped + 1))
    continue
  fi

  ln -sfn "${skill_dir%/}" "$dest"
  echo "  LINK  $skill_name/ -> $dest"
  skills_installed=$((skills_installed + 1))
done

echo ""
echo "Done. $installed command(s), $skills_installed skill(s) installed, $skipped skipped."
echo "Commands are available as /command-name; skills load automatically (or via /skill-name)."
