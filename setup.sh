#!/usr/bin/env bash
# Sets up claude-skills: creates symlinks for skill discovery and registers
# Claude Code hooks. Safe to re-run — skips anything already configured.
#
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"
SETTINGS_FILE="$HOME/.claude/settings.json"

# --- Symlinks ---

echo "=== Skill symlinks ==="
count=0
skipped=0
for dir in "$SCRIPT_DIR"/*/; do
  skill="$(basename "$dir")"
  [ "$skill" = ".git" ] && continue
  if [ -L "$SKILLS_DIR/$skill" ]; then
    echo "  Already linked: $skill"
    skipped=$((skipped + 1))
  else
    ln -sf "$dir" "$SKILLS_DIR/$skill"
    echo "  Linked: $skill"
    count=$((count + 1))
  fi
done
echo "  $count new, $skipped already linked."

# --- Claude Code hooks ---

echo ""
echo "=== Claude Code hooks ==="

HOOK_SCRIPT="$SKILLS_DIR/issue-workflow/hooks/pre-commit-issue-check.sh"

if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "  Skipping hook registration — issue-workflow skill not found."
else
  if ! command -v jq &>/dev/null; then
    echo "  WARNING: jq is required for hook registration but not found. Skipping."
  else
    # Ensure settings.json exists with at least an empty object
    if [ ! -f "$SETTINGS_FILE" ]; then
      echo '{}' > "$SETTINGS_FILE"
      echo "  Created $SETTINGS_FILE"
    fi

    # Check if the hook is already registered
    ALREADY_REGISTERED=$(jq -r --arg cmd "$HOOK_SCRIPT" '
      .hooks.PreToolUse // []
      | map(.hooks // [])
      | flatten
      | map(select(.command == $cmd))
      | length
    ' "$SETTINGS_FILE" 2>/dev/null || echo "0")

    if [ "$ALREADY_REGISTERED" -gt 0 ]; then
      echo "  Hook already registered in settings.json."
    else
      # Add the hook entry
      jq --arg cmd "$HOOK_SCRIPT" '
        .hooks //= {}
        | .hooks.PreToolUse //= []
        | .hooks.PreToolUse += [
            {
              "matcher": "Bash",
              "hooks": [
                {
                  "type": "command",
                  "command": $cmd
                }
              ]
            }
          ]
      ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      echo "  Registered pre-commit-issue-check hook in settings.json."
    fi
  fi
fi

echo ""
echo "Done. Restart Claude Code for changes to take effect."
