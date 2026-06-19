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
SHOW_GIT_AHEAD=${SHOW_GIT_AHEAD:-0}         # ↑N ↓N vs upstream
SHOW_CONTEXT_WARN=${SHOW_CONTEXT_WARN:-0}   # ⚠ quando contexto >= limiar
CONTEXT_WARN_AT=${CONTEXT_WARN_AT:-80}      # limiar do aviso (%)

# Ao trocar de conta (/login) sem reiniciar, o Claude Code segue enviando os rate
# limits da conta antiga. Com isto ligado, ao detectar a troca o script busca os
# rate limits reais da conta ativa direto na API (endpoint experimental, com fallback).
SHOW_LIVE_USAGE=${SHOW_LIVE_USAGE:-1}       # 0 desliga a detecção/busca e mantém o comportamento atual
USAGE_TTL=${USAGE_TTL:-60}                  # TTL (s) do cache da busca de uso na API

# Aparência — defaults preservam o visual atual.
STATUSLINE_SEP=${STATUSLINE_SEP:-|}         # separador entre seções
STATUSLINE_ORDER=${STATUSLINE_ORDER:-}      # ordem custom (csv de chaves); vazio = padrão
STATUSLINE_THEME=${STATUSLINE_THEME:-}      # vazio/"dark" = atual; "light" = cores p/ fundo claro
STATUSLINE_WIDTH=${STATUSLINE_WIDTH:-}      # largura p/ quebra de linha; vazio = detecta (COLUMNS/tput)

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
  L_RESET="resets in"; L_NOW="now"; L_STALE_ACCOUNT="account switched — restart"
else
  L_EFFORT="esforço"; L_CONTEXT="Contexto"; L_SESSION="Sessao"; L_WEEKLY="Semanal"
  L_RESET="reseta em"; L_NOW="agora"; L_STALE_ACCOUNT="conta trocada — reinicie"
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

# ID da sessão (para detectar troca de conta dentro da mesma sessão)
session_id=$(echo "$input" | jq -r '.session_id // .transcript_path // empty')

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

# Converte timestamp ISO 8601 (ex. 2026-06-19T16:20:00.830323+00:00) em epoch.
# A API retorna sempre em UTC; pega os 19 chars 'YYYY-MM-DDTHH:MM:SS' e ignora
# fração/offset (robusto p/ sufixos '.', 'Z', '+hh:mm' e '-hh:mm').
iso_to_epoch() {
  local b="${1:0:19}"
  case "$b" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
    *) return ;;
  esac
  # BSD/macOS (date -j) com fallback p/ GNU/Linux (date -u -d). Ambos interpretam UTC.
  date -j -u -f "%Y-%m-%dT%H:%M:%S" "$b" +%s 2>/dev/null \
    || date -u -d "$b" +%s 2>/dev/null
}

# mtime de um arquivo em epoch. Tenta BSD ('stat -f %m'); se a saída não for
# numérica (ex. no GNU, onde -f é "filesystem status"), cai p/ GNU ('stat -c %Y').
# Só emite se o resultado for realmente numérico.
file_mtime() {
  local out
  out=$(stat -f %m "$1" 2>/dev/null)
  case "$out" in
    ''|*[!0-9]*) out=$(stat -c %Y "$1" 2>/dev/null) ;;
  esac
  case "$out" in
    ''|*[!0-9]*) return 1 ;;
    *) printf '%s\n' "$out" ;;
  esac
}

# Lê o access token OAuth da fonte mais válida (Keychain preferido; arquivo de
# fallback). Só retorna um token cujo expiresAt ainda esteja no futuro.
# Emite o token só se válido e no charset esperado (sk-ant-oat...), evitando
# injeção na config do curl e tokens corrompidos.
emit_token_if_valid() {
  local tok="$1" exp="$2" now_ms="$3"
  [ -z "$tok" ] && return 1
  [ "${exp:-0}" -gt "$now_ms" ] 2>/dev/null || return 1
  case "$tok" in
    *[!A-Za-z0-9._-]*) return 1 ;;
  esac
  printf '%s' "$tok"
}

read_oauth_token() {
  local now_ms kc tok exp f
  now_ms=$(( $(date +%s) * 1000 ))
  kc=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  if [ -n "$kc" ]; then
    tok=$(printf '%s' "$kc" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    exp=$(printf '%s' "$kc" | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null)
    emit_token_if_valid "$tok" "$exp" "$now_ms" && return
  fi
  f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
  if [ -f "$f" ]; then
    tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$f" 2>/dev/null)
    exp=$(jq -r '.claudeAiOauth.expiresAt // 0' "$f" 2>/dev/null)
    emit_token_if_valid "$tok" "$exp" "$now_ms" && return
  fi
}

# Busca o uso real da conta ativa na API (com cache TTL). Usa $state_dir, $USAGE_TTL.
# Imprime "five_pct|five_iso|seven_pct|seven_iso" ou nada em caso de falha.
get_live_usage() {
  local uuid="$1" cache="$state_dir/usage-$1.json" now age resp tok base
  now=$(date +%s)
  if [ -f "$cache" ]; then
    age=$(( now - $(file_mtime "$cache" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$USAGE_TTL" ] 2>/dev/null && resp=$(cat "$cache" 2>/dev/null)
  fi
  if [ -z "$resp" ]; then
    tok=$(read_oauth_token)
    [ -z "$tok" ] && return
    # Host fixo de propósito: é um token de conta (assinatura). Não mandamos para
    # um ANTHROPIC_BASE_URL arbitrário (ex. proxy de inferência) p/ evitar exfiltração.
    base="https://api.anthropic.com"
    # token via --config (stdin) p/ não vazar no ps
    resp=$(printf 'header = "Authorization: Bearer %s"\n' "$tok" | curl -s --max-time 3 --config - \
      -H "anthropic-beta: oauth-2025-04-20" -H "anthropic-version: 2023-06-01" \
      -H "User-Agent: claude-cli-statusline" "$base/api/oauth/usage" 2>/dev/null)
    printf '%s' "$resp" | jq -e '(.five_hour|type=="object") or (.seven_day|type=="object")' >/dev/null 2>&1 || return
    # escrita atômica + permissão restrita (dado de conta/uso)
    ( umask 077; printf '%s' "$resp" > "$cache.tmp.$$" 2>/dev/null ) && mv -f "$cache.tmp.$$" "$cache" 2>/dev/null
  fi
  printf '%s' "$resp" | jq -r '
    def pct(x): (x | (tonumber? // null)) as $n
      | if $n == null then "" elif $n <= 1 then ($n * 100) else $n end;
    [ (pct(.five_hour.utilization) | tostring),
      (.five_hour.resets_at // ""),
      (pct(.seven_day.utilization) | tostring),
      (.seven_day.resets_at // "") ] | join("|")' 2>/dev/null
}

# Branch e worktree do git (+ dirty / ahead-behind, opcionais)
git_branch=""
git_worktree=""
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

# Live usage: detecta troca de conta na mesma sessão e busca os rate limits reais
# da conta ativa na API, sobrescrevendo os números (velhos) vindos do stdin.
stale_account_warn=""
if [ "$SHOW_LIVE_USAGE" != "0" ] && [ -n "$session_id" ]; then
  cfg_json="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}"
  cfg_json="${cfg_json:-$HOME/.claude.json}"
  active_uuid=$(jq -r '.oauthAccount.accountUuid // empty' "$cfg_json" 2>/dev/null)
  state_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-state"
  # active_uuid precisa ser um UUID "limpo" p/ uso seguro em nome de arquivo de cache
  case "$active_uuid" in
    *[!0-9A-Fa-f-]*|"") active_uuid="" ;;
  esac
  if [ -n "$active_uuid" ]; then
    ( umask 077; mkdir -p "$state_dir" 2>/dev/null )
    chmod 700 "$state_dir" 2>/dev/null   # garante privado mesmo se o dir já existia
    # session_id é entrada externa: whitelist de charset p/ nome de arquivo
    sid_key=$(printf '%s' "$session_id" | tr -c 'A-Za-z0-9._-' '_')
    base_file="$state_dir/session-$sid_key"
    baseline=""
    [ -f "$base_file" ] && baseline=$(cat "$base_file" 2>/dev/null)
    # Toca o baseline ANTES do reap p/ uma sessão sem render há >1 dia não perdê-lo.
    touch "$base_file" 2>/dev/null; chmod 600 "$base_file" 2>/dev/null
    # Agora sim reapeia arquivos realmente velhos (o baseline atual acabou de ser tocado)
    find "$state_dir" -type f -mtime +1 -delete 2>/dev/null
    if [ -z "$baseline" ]; then
      ( umask 077; printf '%s' "$active_uuid" > "$base_file" 2>/dev/null )
    elif [ "$baseline" != "$active_uuid" ]; then
      fresh=$(get_live_usage "$active_uuid")
      if [ -n "$fresh" ]; then
        # Houve troca: TODOS os números do stdin são da conta antiga. Zera antes de
        # aplicar os frescos p/ nunca misturar conta nova com conta velha.
        five_pct=""; five_reset=""; seven_pct=""; seven_reset=""
        IFS='|' read -r lf lfi ls lsi <<< "$fresh"
        [ -n "$lf" ]  && five_pct="$lf"
        [ -n "$lfi" ] && five_reset=$(iso_to_epoch "$lfi")
        [ -n "$ls" ]  && seven_pct="$ls"
        [ -n "$lsi" ] && seven_reset=$(iso_to_epoch "$lsi")
      else
        stale_account_warn=1
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
seg_stale=""

# Aviso de conta trocada (fallback quando não foi possível buscar o uso na API)
if [ -n "$stale_account_warn" ]; then
  # ⚠ = U+26A0 puro (largura 1); sem o seletor de variação U+FE0F (vide seg_context)
  seg_stale=$(printf '\033[31m\xe2\x9a\xa0 %s\033[0m' "$L_STALE_ACCOUNT")
fi

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
  seg_git=$(printf '\033[%sm\xf0\x9f\x8c\xbf %s\033[0m' "$C_GIT" "$git_branch")
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
    # ⚠ = U+26A0 puro (largura 1). NÃO usar o seletor de variação U+FE0F (\xef\xb8\x8f):
    # ele faz o host (Claude Code) contar o glifo como 2 colunas enquanto o terminal
    # (xterm.js/Tabby) conta 1, dessincronizando o cursor e corrompendo o texto seguinte.
    [ "$used_int" -ge "$CONTEXT_WARN_AT" ] 2>/dev/null && warn="\xe2\x9a\xa0 "
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

# Aviso de conta trocada sempre primeiro, para ficar evidente
if [ -n "$seg_stale" ]; then
  parts=("$seg_stale" "${parts[@]}")
fi

# Largura visível (em colunas) de uma string, sem códigos ANSI.
# Os emojis 🌿 e 📁 contam como 1 code point mas ocupam 2 colunas, então somamos 1 por ocorrência.
vislen() {
  local s; s=$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')
  local base=${#s}
  local leaf=$'\xf0\x9f\x8c\xbf' fold=$'\xf0\x9f\x93\x81'
  local t1=${s//"$leaf"/} t2=${s//"$fold"/}
  printf '%s' $(( base + (base - ${#t1}) + (base - ${#t2}) ))
}

# Largura do terminal para a quebra de linha (0 = não quebra)
width="$STATUSLINE_WIDTH"
if [ -z "$width" ]; then
  if [ "${COLUMNS:-0}" -gt 0 ] 2>/dev/null; then
    width="$COLUMNS"
  else
    width=$(tput cols 2>/dev/null || echo 0)
  fi
fi
[ -z "$width" ] && width=0
# margem de 1 coluna: a largura de emoji varia entre terminais e o truncamento
# pode reservar uma coluna — evita cortar bem no limite.
[ "$width" -gt 0 ] 2>/dev/null && width=$((width - 1))

sep=$(printf ' \033[%sm%s\033[0m ' "$C_DIM" "$STATUSLINE_SEP")
sep_len=$(( $(vislen "$sep") ))

# Junta as seções, quebrando linha quando não couber na largura
out=""
line=""
line_len=0
for seg in "${parts[@]}"; do
  seg_len=$(vislen "$seg")
  if [ -z "$line" ]; then
    line="$seg"; line_len="$seg_len"
  elif [ "$width" -gt 0 ] && [ $((line_len + sep_len + seg_len)) -gt "$width" ]; then
    out="$out$line"$'\n'
    line="$seg"; line_len="$seg_len"
  else
    line="$line$sep$seg"; line_len=$((line_len + sep_len + seg_len))
  fi
done
out="$out$line"
printf '%s\n' "$out"
