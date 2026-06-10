#!/usr/bin/env bash
# Claude Code status line — informações de uso em PT-BR
input=$(cat)

# Model
model=$(echo "$input" | jq -r '.model.display_name // "?"')

# Effort
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Context window
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

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
    printf 'agora'
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

parts=()

# Modelo (+ esforço atual)
if [ -n "$effort" ]; then
  case "$effort" in
    low) effort_str="baixo" ;;
    medium) effort_str="médio" ;;
    high) effort_str="alto" ;;
    xhigh) effort_str="extra-alto" ;;
    max) effort_str="máximo" ;;
    *) effort_str="$effort" ;;
  esac
  parts+=("$(printf '\033[35m%s\033[0m \033[90m(esforço %s)\033[0m' "$model" "$effort_str")")
else
  parts+=("$(printf '\033[35m%s\033[0m' "$model")")
fi

# Contexto
if [ -n "$used_pct" ]; then
  parts+=("$(printf 'Contexto: ')$(color_pct "$used_pct")")
fi

# Sessao (5h rate limit)
if [ -n "$five_pct" ]; then
  reset_str=$(fmt_reset "$five_reset")
  label="Sessao: $(color_pct "$five_pct")"
  if [ -n "$reset_str" ]; then
    label="$label$(printf ' \033[90m(reseta em %s)\033[0m' "$reset_str")"
  fi
  parts+=("$label")
fi

# Semanal (7d rate limit)
if [ -n "$seven_pct" ]; then
  reset_str=$(fmt_reset "$seven_reset")
  label="Semanal: $(color_pct "$seven_pct")"
  if [ -n "$reset_str" ]; then
    label="$label$(printf ' \033[90m(reseta em %s)\033[0m' "$reset_str")"
  fi
  parts+=("$label")
fi

# Join with separator
printf '%s' "${parts[0]}"
for ((i=1; i<${#parts[@]}; i++)); do
  printf ' \033[90m|\033[0m %s' "${parts[$i]}"
done
printf '\n'
