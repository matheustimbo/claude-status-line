# claude-status-line

**PT-BR** · [EN](README.en.md)

Status line em PT-BR para o [Claude Code](https://claude.com/claude-code) mostrando modelo, nível de esforço atual, uso de contexto e rate limits (sessão de 5h e semanal de 7d), com cores e tempo até o reset.

Exemplo:

```
Opus 4.7 (1M context) (esforço alto) | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 18% (reseta em 5d 13h)
```

Cores: verde (<50%), amarelo (<80%), vermelho (≥80%).

## Requisitos

- `bash`, `curl`
- [`jq`](https://stedolan.github.io/jq/) — `brew install jq` (macOS) ou `apt install jq` (Linux)

## Instalação (uma linha)

```bash
curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

Depois reinicie o Claude Code. O instalador baixa o script pra `~/.claude/statusline-command.sh` e adiciona o bloco `statusLine` ao seu `~/.claude/settings.json` (preservando o que já estiver lá).

O default usa `refreshInterval: 5` (atualiza a cada 5s — útil quando você tem vários terminais em paralelo e quer que a linha esteja fresca quando troca de janela). Pra mudar, passe a env var:

```bash
REFRESH_INTERVAL=10 curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

> Sem custo de API ou tokens — a status line é renderizada localmente. CPU é desprezível mesmo com 10+ janelas abertas.

### Instalação manual

<details>
<summary>Se preferir não rodar o script</summary>

1. Baixe o script pra `~/.claude/`:

   ```bash
   curl -o ~/.claude/statusline-command.sh \
     https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Adicione o bloco `statusLine` no seu `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline-command.sh"
     }
   }
   ```

3. Reinicie o Claude Code.

</details>

## Como funciona

O Claude Code envia um JSON via stdin pra cada execução da status line, contendo `model`, `effort`, `context_window` e `rate_limits`. O script lê com `jq` e formata em PT-BR com ANSI colors.

## Licença

MIT
