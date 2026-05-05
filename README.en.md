# claude-status-line

PT-BR ([README](README.md)) · **EN**

A Portuguese (BR) status line for [Claude Code](https://claude.com/claude-code) showing the active model, context window usage, and rate limits (5-hour session and 7-day weekly), with colors and time until reset.

Example:

```
Opus 4.7 (1M context) | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 18% (reseta em 5d 13h)
```

Colors: green (<50%), yellow (<80%), red (≥80%).

> Labels are in Portuguese (`Contexto`, `Sessao`, `Semanal`, `reseta em`). If you want them in English, edit `statusline-command.sh` directly — it's a small bash script.

## Requirements

- `bash`
- [`jq`](https://stedolan.github.io/jq/) — `brew install jq` (macOS) or `apt install jq` (Linux)

## Installation

1. Copy the script to `~/.claude/`:

   ```bash
   curl -o ~/.claude/statusline-command.sh \
     https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Add the `statusLine` block to your `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline-command.sh"
     }
   }
   ```

3. Restart Claude Code.

## How it works

Claude Code pipes a JSON payload via stdin to the status line command on every render, containing `model`, `context_window`, and `rate_limits`. The script parses it with `jq` and prints a formatted line with ANSI colors.

## License

MIT
