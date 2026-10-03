const EFFORT_LABELS = {
  low: 'baixo',
  medium: 'médio',
  high: 'alto',
  xhigh: 'extra-alto',
  max: 'máximo',
}

const RATE_LIMIT_LABELS = [
  ['five_hour', 'Sessao'],
  ['seven_day', 'Semanal'],
]

const LONG_CONTEXT = /\[1m\]$/i
const DATED_SNAPSHOT = /-\d{8}$/
const FAMILY_FIRST = /^claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?$/
const VERSION_FIRST = /^claude-(\d+)(?:-(\d{1,2}))?-([a-z]+)$/

function capitalize(word) {
  return word[0].toUpperCase() + word.slice(1)
}

export function modelLabel(model) {
  const longContext = LONG_CONTEXT.test(model)
  const id = model.replace(LONG_CONTEXT, '').replace(DATED_SNAPSHOT, '')
  let family, major, minor
  let match = FAMILY_FIRST.exec(id)
  if (match) [, family, major, minor] = match
  else if ((match = VERSION_FIRST.exec(id))) [, major, minor, family] = match
  else return model
  const name = `${capitalize(family)} ${minor ? `${major}.${minor}` : major}`
  return longContext ? `${name} (1M context)` : name
}

// printf '%.0f' in the bash script rounds ties to even
function roundHalfEven(value) {
  const floor = Math.floor(value)
  const fraction = value - floor
  if (fraction > 0.5) return floor + 1
  if (fraction < 0.5) return floor
  return floor % 2 === 0 ? floor : floor + 1
}

export function formatPct(value) {
  return `${roundHalfEven(value)}%`
}

export function pctColor(pct) {
  const rounded = roundHalfEven(pct)
  if (rounded >= 80) return 'red'
  if (rounded >= 50) return 'yellow'
  return 'green'
}

export function formatReset(resetsAt, now) {
  if (!resetsAt) return undefined
  const diff = Math.floor((Date.parse(resetsAt) - now) / 1000)
  if (diff <= 0) return 'agora'
  const days = Math.floor(diff / 86400)
  const hours = Math.floor((diff % 86400) / 3600)
  const mins = Math.floor((diff % 3600) / 60)
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${mins}min`
  return `${mins}min`
}

export function effortLabel(effort) {
  return EFFORT_LABELS[effort] ?? String(effort)
}

function pct(value) {
  return { text: formatPct(value), color: pctColor(value) }
}

export function segments({ model, effort, context, rateLimits, now }) {
  const parts = []

  const modelPart = [{ text: modelLabel(model), color: 'magenta' }]
  if (effort !== undefined) modelPart.push({ text: ` (esforço ${effortLabel(effort)})`, dim: true })
  parts.push(modelPart)

  if (context?.percent !== undefined) parts.push([{ text: 'Contexto: ' }, pct(context.percent)])

  for (const [kind, label] of RATE_LIMIT_LABELS) {
    const limit = rateLimits.find((l) => l.kind === kind)
    if (!limit) continue
    const part = [{ text: `${label}: ` }, pct(limit.percentUsed)]
    const reset = formatReset(limit.resetsAt, now)
    if (reset) part.push({ text: ` (reseta em ${reset})`, dim: true })
    parts.push(part)
  }

  return parts
}
