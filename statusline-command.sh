#!/usr/bin/env bash
# Claude Code status line
#
# Toggle de seções: defina como 0 para esconder (padrão das seções base: ligadas).
# Ex. no settings.json: "command": "SHOW_WEEKLY=0 bash ~/.claude/statusline-command.sh"
SHOW_MODEL=${SHOW_MODEL:-1}
SHOW_EFFORT=${SHOW_EFFORT:-1}
SHOW_GIT=${SHOW_GIT:-1}
SHOW_CONTEXT=${SHOW_CONTEXT:-1}
SHOW_SESSION=${SHOW_SESSION:-1}
SHOW_WEEKLY=${SHOW_WEEKLY:-1}

# Seções/recursos extras — desligados por padrão.
SHOW_COST=${SHOW_COST:-0}                   # custo da sessão ($.cost.total_cost_usd)
SHOW_GIT_DIRTY=${SHOW_GIT_DIRTY:-0}         # marca '*' quando há mudanças não commitadas
SHOW_GIT_AHEAD=${SHOW_GIT_AHEAD:-0}         # ↑N ↓N vs upstream
SHOW_CONTEXT_WARN=${SHOW_CONTEXT_WARN:-0}   # ⚠️ quando contexto >= limiar
CONTEXT_WARN_AT=${CONTEXT_WARN_AT:-80}      # limiar do aviso (%)

# Aparência — defaults preservam o visual atual.
STATUSLINE_SEP=${STATUSLINE_SEP:-|}         # separador entre seções
STATUSLINE_ORDER=${STATUSLINE_ORDER:-}      # ordem custom (csv de chaves); vazio = padrão
STATUSLINE_THEME=${STATUSLINE_THEME:-}      # vazio/"dark" = atual; "light" = cores p/ fundo claro

# Tema de cores (códigos ANSI). color_pct (verde/amarelo/vermelho) é universal.
if [ "$STATUSLINE_THEME" = "light" ]; then
  C_MODEL=35; C_GIT=34; C_DIM=30
else
  C_MODEL=35; C_GIT=36; C_DIM=90
fi

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

# Custo
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

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

# Format reset time as relative duration (e.g., "em 2h 15min")
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

# Branch e worktree do git (+ dirty / ahead-behind, opcionais)
git_branch=""
git_worktree=""
git_dirty=""
git_ahead_behind=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$git_branch" ]; then
    # HEAD destacado: usa o hash curto
    git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  fi
  if [ -n "$git_branch" ]; then
    # Nome da worktree atual (basename do topo da worktree)
    wt_top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$wt_top" ]; then
      # Mostra a worktree apenas se nao for a principal
      main_top=$(git -C "$cwd" worktree list 2>/dev/null | head -n1 | awk '{print $1}')
      if [ -n "$main_top" ] && [ "$wt_top" != "$main_top" ]; then
        git_worktree=$(basename "$wt_top")
      fi
    fi
    # Repo com mudanças não commitadas
    if [ "$SHOW_GIT_DIRTY" != "0" ] && [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
      git_dirty="*"
    fi
    # Ahead/behind vs upstream
    if [ "$SHOW_GIT_AHEAD" != "0" ]; then
      counts=$(git -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
      if [ -n "$counts" ]; then
        behind=$(printf '%s' "$counts" | awk '{print $1}')
        ahead=$(printf '%s' "$counts" | awk '{print $2}')
        ab=""
        [ "${ahead:-0}" -gt 0 ] 2>/dev/null && ab="$ab\xe2\x86\x91$ahead"
        [ "${behind:-0}" -gt 0 ] 2>/dev/null && ab="$ab${ab:+ }\xe2\x86\x93$behind"
        [ -n "$ab" ] && git_ahead_behind="$ab"
      fi
    fi
  fi
fi

# Monta cada seção numa variável seg_<key> (vazio = oculta) -------------------
seg_model=""
seg_git=""
seg_context=""
seg_session=""
seg_weekly=""
seg_cost=""

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
    seg_model=$(printf '\033[%sm%s\033[0m \033[%sm(%s %s)\033[0m' "$C_MODEL" "$model" "$C_DIM" "$L_EFFORT" "$effort_str")
  else
    seg_model=$(printf '\033[%sm%s\033[0m' "$C_MODEL" "$model")
  fi
fi

# Branch / worktree
if [ "$SHOW_GIT" != "0" ] && [ -n "$git_branch" ]; then
  seg_git=$(printf '\033[%sm\xf0\x9f\x8c\xbf %s%s\033[0m' "$C_GIT" "$git_branch" "$git_dirty")
  if [ -n "$git_ahead_behind" ]; then
    seg_git="$seg_git$(printf ' \033[%sm%b\033[0m' "$C_DIM" "$git_ahead_behind")"
  fi
  if [ -n "$git_worktree" ]; then
    seg_git="$seg_git$(printf ' \033[%sm(\xf0\x9f\x93\x81 %s)\033[0m' "$C_DIM" "$git_worktree")"
  fi
fi

# Contexto
if [ "$SHOW_CONTEXT" != "0" ] && [ -n "$used_pct" ]; then
  warn=""
  if [ "$SHOW_CONTEXT_WARN" != "0" ]; then
    used_int=$(printf "%.0f" "$used_pct")
    [ "$used_int" -ge "$CONTEXT_WARN_AT" ] 2>/dev/null && warn="\xe2\x9a\xa0\xef\xb8\x8f "
  fi
  seg_context="$(printf '%b%s: ' "$warn" "$L_CONTEXT")$(color_pct "$used_pct")"
fi

# Sessao (5h rate limit)
if [ "$SHOW_SESSION" != "0" ] && [ -n "$five_pct" ]; then
  reset_str=$(fmt_reset "$five_reset")
  seg_session="$L_SESSION: $(color_pct "$five_pct")"
  if [ -n "$reset_str" ]; then
    seg_session="$seg_session$(printf ' \033[%sm(%s %s)\033[0m' "$C_DIM" "$L_RESET" "$reset_str")"
  fi
fi

# Semanal (7d rate limit)
if [ "$SHOW_WEEKLY" != "0" ] && [ -n "$seven_pct" ]; then
  reset_str=$(fmt_reset "$seven_reset")
  seg_weekly="$L_WEEKLY: $(color_pct "$seven_pct")"
  if [ -n "$reset_str" ]; then
    seg_weekly="$seg_weekly$(printf ' \033[%sm(%s %s)\033[0m' "$C_DIM" "$L_RESET" "$reset_str")"
  fi
fi

# Custo da sessão
if [ "$SHOW_COST" != "0" ] && [ -n "$cost" ]; then
  seg_cost=$(LC_ALL=C awk -v c="$C_DIM" -v v="$cost" 'BEGIN{printf "\033[%sm$%.2f\033[0m", c, v}')
fi

# Ordena e junta -------------------------------------------------------------
default_order="model git context session weekly cost"
order="${STATUSLINE_ORDER:-$default_order}"
order="${order//,/ }"

parts=()
for key in $order; do
  case "$key" in
    model)   seg="$seg_model" ;;
    git)     seg="$seg_git" ;;
    context) seg="$seg_context" ;;
    session) seg="$seg_session" ;;
    weekly)  seg="$seg_weekly" ;;
    cost)    seg="$seg_cost" ;;
    *)       seg="" ;;
  esac
  [ -n "$seg" ] && parts+=("$seg")
done

# Join com separador configurável
if [ "${#parts[@]}" -gt 0 ]; then
  printf '%s' "${parts[0]}"
  for ((i=1; i<${#parts[@]}; i++)); do
    printf ' \033[%sm%s\033[0m %s' "$C_DIM" "$STATUSLINE_SEP" "${parts[$i]}"
  done
fi
printf '\n'
