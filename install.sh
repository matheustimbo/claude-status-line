#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SCRIPT_PATH="${CLAUDE_DIR}/statusline-command.sh"
SETTINGS_PATH="${CLAUDE_DIR}/settings.json"
RAW_URL="https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/statusline-command.sh"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-5}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  echo "  macOS: brew install jq" >&2
  echo "  Linux: apt install jq  (or your distro equivalent)" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"

echo "Downloading status line script to $SCRIPT_PATH"
curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

STATUSLINE_BLOCK=$(jq -n --argjson ri "$REFRESH_INTERVAL" '{
  type: "command",
  command: "bash ~/.claude/statusline-command.sh",
  refreshInterval: $ri
}')

if [ -f "$SETTINGS_PATH" ]; then
  echo "Updating $SETTINGS_PATH (statusLine block, refreshInterval=${REFRESH_INTERVAL}s)"
  tmp=$(mktemp)
  jq --argjson sl "$STATUSLINE_BLOCK" '.statusLine = $sl' "$SETTINGS_PATH" > "$tmp"
  mv "$tmp" "$SETTINGS_PATH"
else
  echo "Creating $SETTINGS_PATH (refreshInterval=${REFRESH_INTERVAL}s)"
  jq -n --argjson sl "$STATUSLINE_BLOCK" '{statusLine: $sl}' > "$SETTINGS_PATH"
fi

echo
echo "Done. Restart Claude Code to see the status line."
