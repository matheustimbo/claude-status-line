#!/usr/bin/env bash
# Claude Code status line — informações de uso em PT-BR
#
# Toggle de seções: defina como 0 para esconder (padrão: todas ligadas).
# Ex. no settings.json: "command": "SHOW_WEEKLY=0 bash ~/.claude/statusline-command.sh"
SHOW_MODEL=${SHOW_MODEL:-1}
SHOW_EFFORT=${SHOW_EFFORT:-1}
SHOW_GIT=${SHOW_GIT:-1}
SHOW_CONTEXT=${SHOW_CONTEXT:-1}
SHOW_SESSION=${SHOW_SESSION:-1}
SHOW_WEEKLY=${SHOW_WEEKLY:-1}

# Idioma dos rótulos: "pt" ou "en".
# Padrão: idioma do sistema; se não for suportado, cai pra "en".
# Para forçar, no settings.json: "command": "STATUSLINE_LANG=pt bash ~/.claude/statusline-command.sh"
detect_lang() {
  local sys="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  if [ -z "$sys" ] && command -v defaults >/dev/null 2>&1; then
    sys=$(defaults read -g AppleLocale 2>/dev/null)
  fi
  case "$sys" in
    pt*) printf 'pt' ;;
    *)   printf 'en' ;;
  esac
}
STATUSLINE_LANG=${STATUSLINE_LANG:-$(detect_lang)}

if [ "$STATUSLINE_LANG" = "en" ]; then
  L_EFFORT="effort"; L_CONTEXT="Context"; L_SESSION="Session"; L_WEEKLY="Weekly"
  L_RESET="resets in"; L_NOW="now"
else
  L_EFFORT="esforço"; L_CONTEXT="Contexto"; L_SESSION="Sessao"; L_WEEKLY="Semanal"
  L_RESET="reseta em"; L_NOW="agora"
fi

input=$(cat)

# Model
model=$(echo "$input" | jq -r '.model.display_name // "?"')

# Effort
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Context window
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Diretorio atual (para info de git)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# Rate limits
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Color helper: green < 50%, yellow < 80%, red >= 80%
color_pct() {
  local val=$(printf "%.0f" "$1")
  if [ "$val" -ge 80 ]; then
    printf '\033[31m%s%%\033[0m' "$val"
  elif [ "$val" -ge 50 ]; then
    printf '\033[33m%s%%\033[0m' "$val"
  else
    printf '\033[32m%s%%\033[0m' "$val"
  fi
}

# Format reset time as relative duration (e.g., "em 2h 15min") or absolute if > 24h
fmt_reset() {
  local reset_ts=$1
  if [ -z "$reset_ts" ] || [ "$reset_ts" = "null" ]; then return; fi
  local now=$(date +%s)
  local diff=$((reset_ts - now))
  if [ "$diff" -le 0 ]; then
    printf '%s' "$L_NOW"
    return
  fi
  local days=$((diff / 86400))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf '%dd %dh' "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh %dmin' "$hours" "$mins"
  else
    printf '%dmin' "$mins"
  fi
}

# Branch e worktree do git
git_branch=""
git_worktree=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$git_branch" ]; then
    # HEAD destacado: usa o hash curto
    git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  fi
  # Nome da worktree atual (basename do topo da worktree)
  wt_top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$wt_top" ]; then
    # Mostra a worktree apenas se nao for a principal
    main_top=$(git -C "$cwd" worktree list 2>/dev/null | head -n1 | awk '{print $1}')
    if [ -n "$main_top" ] && [ "$wt_top" != "$main_top" ]; then
      git_worktree=$(basename "$wt_top")
    fi
  fi
fi

parts=()

# Modelo (+ esforço atual)
if [ "$SHOW_MODEL" != "0" ]; then
  if [ "$SHOW_EFFORT" != "0" ] && [ -n "$effort" ]; then
    if [ "$STATUSLINE_LANG" = "en" ]; then
      case "$effort" in
        low) effort_str="low" ;;
        medium) effort_str="medium" ;;
        high) effort_str="high" ;;
        xhigh) effort_str="extra-high" ;;
        max) effort_str="max" ;;
        *) effort_str="$effort" ;;
      esac
    else
      case "$effort" in
        low) effort_str="baixo" ;;
        medium) effort_str="médio" ;;
        high) effort_str="alto" ;;
        xhigh) effort_str="extra-alto" ;;
        max) effort_str="máximo" ;;
        *) effort_str="$effort" ;;
      esac
    fi
    parts+=("$(printf '\033[35m%s\033[0m \033[90m(%s %s)\033[0m' "$model" "$L_EFFORT" "$effort_str")")
  else
    parts+=("$(printf '\033[35m%s\033[0m' "$model")")
  fi
fi

# Branch / worktree
if [ "$SHOW_GIT" != "0" ] && [ -n "$git_branch" ]; then
  branch_label=$(printf '\033[36m\xf0\x9f\x8c\xbf %s\033[0m' "$git_branch")
  if [ -n "$git_worktree" ]; then
    branch_label="$branch_label$(printf ' \033[90m(\xf0\x9f\x93\x81 %s)\033[0m' "$git_worktree")"
  fi
  parts+=("$branch_label")
fi

# Contexto
if [ "$SHOW_CONTEXT" != "0" ] && [ -n "$used_pct" ]; then
  parts+=("$(printf '%s: ' "$L_CONTEXT")$(color_pct "$used_pct")")
fi

# Sessao (5h rate limit)
if [ "$SHOW_SESSION" != "0" ] && [ -n "$five_pct" ]; then
  reset_str=$(fmt_reset "$five_reset")
  label="$L_SESSION: $(color_pct "$five_pct")"
  if [ -n "$reset_str" ]; then
    label="$label$(printf ' \033[90m(%s %s)\033[0m' "$L_RESET" "$reset_str")"
  fi
  parts+=("$label")
fi

# Semanal (7d rate limit)
if [ "$SHOW_WEEKLY" != "0" ] && [ -n "$seven_pct" ]; then
  reset_str=$(fmt_reset "$seven_reset")
  label="$L_WEEKLY: $(color_pct "$seven_pct")"
  if [ -n "$reset_str" ]; then
    label="$label$(printf ' \033[90m(%s %s)\033[0m' "$L_RESET" "$reset_str")"
  fi
  parts+=("$label")
fi

# Join with separator
printf '%s' "${parts[0]}"
for ((i=1; i<${#parts[@]}; i++)); do
  printf ' \033[90m|\033[0m %s' "${parts[$i]}"
done
printf '\n'
