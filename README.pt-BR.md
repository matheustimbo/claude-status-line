<div align="center">

# 📊 claude-status-line

**Status line em PT-BR para o [Claude Code](https://claude.com/claude-code)** — saiba sempre quanto resta dos seus rate limits, sem sair do terminal.

[![Instalação em uma linha](https://img.shields.io/badge/instala%C3%A7%C3%A3o-uma%20linha-brightgreen)](#-instalação-uma-linha)
[![Shell](https://img.shields.io/badge/feito%20em-bash%20%2B%20jq-blue)](statusline-command.sh)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-yellow)](LICENSE)
[![PT-BR](https://img.shields.io/badge/idioma-PT--BR-green)](README.pt-BR.md)

[EN](README.md) · **PT-BR**

</div>

---

Mostra **modelo**, **nível de esforço**, **branch e worktree atual do git**, **uso de contexto** e **rate limits** (sessão de 5h e semanal de 7d), com cores e tempo até o reset:

```
Opus 4.7 (1M context) (esforço alto) | 🌿 main | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 18% (reseta em 5d 13h)
```

A branch mostra o nome da worktree entre parênteses quando você está numa worktree secundária (ex: `🌿 feature-x (📁 minha-worktree)`). Não precisa de fonte especial — funciona em qualquer terminal.

🟢 verde (<50%) · 🟡 amarelo (<80%) · 🔴 vermelho (≥80%)

## ✨ Por quê?

- ⏱️ **Nunca mais seja surpreendido pelo rate limit** — veja sessão e semanal em tempo real, com countdown até o reset
- 🧠 **Contexto sempre visível** — saiba quando está na hora de compactar
- 🌿 **Branch e worktree à vista** — sempre saiba em qual branch (e worktree) você está
- 🪶 **Zero custo** — sem API, sem tokens; tudo renderizado localmente, CPU desprezível mesmo com 10+ janelas abertas
- 🇧🇷 **Em português**, do jeito que a gente fala

## 📦 Requisitos

- `bash`, `curl`
- [`jq`](https://stedolan.github.io/jq/) — `brew install jq` (macOS) ou `apt install jq` (Linux)

## 🚀 Instalação (uma linha)

```bash
curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

Depois reinicie o Claude Code. O instalador baixa o script pra `~/.claude/statusline-command.sh` e adiciona o bloco `statusLine` ao seu `~/.claude/settings.json` (preservando o que já estiver lá).

O default usa `refreshInterval: 5` (atualiza a cada 5s — útil quando você tem vários terminais em paralelo e quer que a linha esteja fresca quando troca de janela). Pra mudar, passe a env var:

```bash
REFRESH_INTERVAL=10 curl -fsSL https://raw.githubusercontent.com/matheustimbo/claude-status-line/main/install.sh | bash
```

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

## ⚙️ Como funciona

O Claude Code envia um JSON via stdin pra cada execução da status line, contendo `model`, `effort`, `workspace`, `context_window` e `rate_limits`. O script lê com `jq` (e chama o `git` pra branch/worktree) e formata em PT-BR com ANSI colors. Simples assim — um único arquivo bash, fácil de customizar.

## 📄 Licença

MIT — use, modifique e compartilhe à vontade.

---

<div align="center">

Feito com ☕ por [@matheustimbo](https://github.com/matheustimbo) — se te ajudou, deixa uma ⭐!

</div>
