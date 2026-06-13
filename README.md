<div align="center">

# 📊 claude-status-line

**A Portuguese (BR) status line for [Claude Code](https://claude.com/claude-code)** — always know your model, git branch/worktree, and how much of your rate limits is left, without leaving the terminal.

[![One-line install](https://img.shields.io/badge/install-one%20line-brightgreen)](#-one-line-install)
[![Shell](https://img.shields.io/badge/built%20with-bash%20%2B%20jq-blue)](statusline-command.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)
[![PT-BR](https://img.shields.io/badge/language-PT--BR-green)](README.pt-BR.md)

**EN** · [PT-BR](README.pt-BR.md)

</div>

---

Shows the **active model**, **current effort level**, **current git branch and worktree**, **context window usage**, and **rate limits** (5-hour session and 7-day weekly), with colors and time until reset:

```
Opus 4.8 (1M context) (esforço alto) | 🌿 main | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 18% (reseta em 5d 13h)
```

In a secondary git worktree, the worktree name (📁) appears in parentheses next to the branch (🌿):

```
Opus 4.8 (1M context) (esforço alto) | 🌿 feature-x (📁 my-worktree) | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 18% (reseta em 5d 13h)
```

No special font required — it works in any terminal.

🟢 green (<50%) · 🟡 yellow (<80%) · 🔴 red (≥80%)

> Labels follow your system language (Portuguese or English), and fall back to English otherwise. Force one with `STATUSLINE_LANG` — see [Configuration](#%EF%B8%8F-configuration).

## ✨ Why?

- ⏱️ **Never get surprised by a rate limit again** — see session and weekly usage in real time, with a countdown to reset
- 🧠 **Context always visible** — know when it's time to compact
- 🌿 **Branch & worktree at a glance** — always know which branch (and worktree) you're working in
- 🪶 **Zero cost** — no API, no tokens; everything rendered locally, negligible CPU even with 10+ windows open

## 📦 Requirements

- `bash`, `curl`
- [`jq`](https://stedolan.github.io/jq/) — `brew install jq` (macOS) or `apt install jq` (Linux)

## 🚀 One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

Then restart Claude Code. The installer downloads the script to `~/.claude/statusline-command.sh` and adds the `statusLine` block to your `~/.claude/settings.json` (preserving any existing config).

The default uses `refreshInterval: 5` (refresh every 5s — useful when you have multiple terminals running in parallel and want the line to be fresh when you switch windows). Override via env var:

```bash
REFRESH_INTERVAL=10 curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

### Manual install

<details>
<summary>If you'd rather not pipe a script to bash</summary>

1. Download the script to `~/.claude/`:

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

</details>

## 🎛️ Configuration

The status line is configured via environment variables in the `command` of your `~/.claude/settings.json`. Chain as many as you like:

```json
{
  "statusLine": {
    "type": "command",
    "command": "STATUSLINE_LANG=en SHOW_WEEKLY=0 bash ~/.claude/statusline-command.sh"
  }
}
```

**Language** — `STATUSLINE_LANG`: `pt` or `en`. Defaults to your system language (from `LANG`/`LC_*` or macOS `AppleLocale`), falling back to English if it isn't supported.

**Toggle sections** — set any of these to `0` to hide it (all shown by default):

| Variable        | Section                        |
| --------------- | ------------------------------ |
| `SHOW_MODEL`    | Model name                     |
| `SHOW_EFFORT`   | Effort level (next to model)   |
| `SHOW_GIT`      | Git branch / worktree          |
| `SHOW_CONTEXT`  | Context window usage           |
| `SHOW_SESSION`  | 5-hour session rate limit      |
| `SHOW_WEEKLY`   | 7-day weekly rate limit        |

## ⚙️ How it works

Claude Code pipes a JSON payload via stdin to the status line command on every render, containing `model`, `effort`, `workspace`, `context_window`, and `rate_limits`. The script parses it with `jq` (and shells out to `git` for the branch/worktree) and prints a formatted line with ANSI colors. That's it — a single bash file, easy to customize.

## 📄 License

MIT — use, modify, and share freely.

---

<div align="center">

Made with ☕ by [@matheustimbo](https://github.com/matheustimbo) — if this helped you, drop a ⭐!

</div>
