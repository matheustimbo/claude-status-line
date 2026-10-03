import { segments } from './format.js'

const RESET_COUNTDOWN_MS = 30_000

// Effort the main loop last sent, and the model it was sent with
let observed

function modelKey(model) {
  return model.replace(/\[.*\]$/, '')
}

async function settingsEffort($, key) {
  const settings = await $.settings.read()
  const level = settings.modelSettings?.[key]?.effortLevel ?? settings.effortLevel
  return typeof level === 'string' ? level : undefined
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    $.clock.every(RESET_COUNTDOWN_MS, () => $.ui.invalidate('ui.render'))
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined) {
      observed = { model: modelKey(e.model), effort: e.effort }
      $.ui.invalidate('ui.render')
    }
    return yield* next(e)
  })

  on('session.measure', async ($, e, next) => {
    $.ui.invalidate('ui.render')
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const { Box, Text } = $.ui.resolve(e)
    const [model, usage, now, others] = await Promise.all([
      $.session.model(),
      $.session.usage(),
      $.clock.now(),
      next(e),
    ])
    const key = modelKey(model)
    if (observed && observed.model !== key) observed = undefined
    const effort = observed ? observed.effort : await settingsEffort($, key)
    const parts = segments({ model, effort, context: usage.context, rateLimits: usage.rateLimits, now })

    const children = []
    parts.forEach((part, i) => {
      if (i > 0) children.push(Text({ dimColor: true, children: [' | '] }))
      for (const s of part) {
        const props = { children: [s.text] }
        if (s.color) props.color = s.color
        if (s.dim) props.dimColor = true
        children.push(Text(props))
      }
    })

    const line = Box({ flexDirection: 'row', flexWrap: 'wrap', children })
    return others ? Box({ flexDirection: 'column', children: [others, line] }) : line
  })
}
