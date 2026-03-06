#!/bin/bash
# .claude/hooks/pre-commit-issue-check.sh
#
# PreToolUse advisory hook for Claude Code.
# Injects open-issue context when Claude is about to run `git commit`
# without an issue reference (#N) in the command.
#
# Always exits 0 — purely advisory, never blocks.
# Depends on: jq

set -euo pipefail

# Read the JSON payload from Claude Code on stdin
INPUT=$(cat)

# Extract the command string from tool_input.command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Gate 1: Not a git commit command → silent exit
# Matches both `git commit` and `git.exe commit`
if ! echo "$COMMAND" | grep -qE '^\s*git(\.exe)?\s+commit\b'; then
  exit 0
fi

# Gate 2: Command already contains an issue reference (#<number>) → silent exit
if echo "$COMMAND" | grep -qE '#[0-9]+'; then
  exit 0
fi

# Resolve project directory — CLAUDE_PROJECT_DIR if set, else git root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# Resolve manifest directory from CLAUDE.md or default
MANIFEST_DIR="$PROJECT_DIR/.claude/issues"
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  CUSTOM_PATH=$(grep -oP 'issueManifestPath:\s*\K\S+' "$PROJECT_DIR/CLAUDE.md" || true)
  if [ -n "$CUSTOM_PATH" ]; then
    MANIFEST_DIR="$PROJECT_DIR/$CUSTOM_PATH"
  fi
fi

# Gate 3: No manifest directory or no JSON files → silent exit
if [ ! -d "$MANIFEST_DIR" ]; then
  exit 0
fi
shopt -s nullglob
MANIFESTS=("$MANIFEST_DIR"/*.json)
shopt -u nullglob
if [ ${#MANIFESTS[@]} -eq 0 ]; then
  exit 0
fi

# Collect open issues from all manifests
OPEN_ISSUES=""
for manifest in "${MANIFESTS[@]}"; do
  ISSUES=$(jq -r '
    .issues[]?
    | select(.status == "open")
    | "  - #\(.number) [\(.type // "unknown")]: \(.title)"
  ' "$manifest" 2>/dev/null || true)
  if [ -n "$ISSUES" ]; then
    OPEN_ISSUES="${OPEN_ISSUES}${ISSUES}\n"
  fi
done

# No open issues → silent exit
if [ -z "$OPEN_ISSUES" ]; then
  exit 0
fi

# Format the issue list (strip trailing newline)
ISSUE_LIST=$(echo -e "$OPEN_ISSUES" | sed '/^$/d')

# Output advisory context as structured JSON
jq -n --arg issues "$ISSUE_LIST" '{
  additionalContext: (
    "OPEN ISSUES — Your commit message should reference one of these:\n"
    + $issues + "\n\n"
    + "Commit message format:\n"
    + "  Fixes #<number>  — if the commit resolves the issue\n"
    + "  Ref #<number>    — if the commit is related but does not resolve it\n\n"
    + "If this commit is truly unrelated to any open issue, proceed as-is."
  )
}'

exit 0
